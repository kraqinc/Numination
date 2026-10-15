import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'env.dart';
import 'error_messages.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiRequestCancelled implements Exception {
  const ApiRequestCancelled();

  @override
  String toString() => 'ApiRequestCancelled';
}

/// Token para cancelar UNA solicitud concreta.
/// No cancela accidentalmente las solicitudes de otras pantallas.
class ApiCancelToken {
  bool _cancelled = false;
  http.Client? _client;

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;

    _cancelled = true;
    _client?.close();
    _client = null;
  }

  void _attach(http.Client client) {
    if (_cancelled) {
      client.close();
      return;
    }

    _client = client;
  }

  void _detach(http.Client client) {
    if (identical(_client, client)) {
      _client = null;
    }
  }
}

class ApiClient {
  static const _delays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  static String? _token;

  static void setLanguageCode(String languageCode) =>
      AppErrorMessages.setLanguageCode(languageCode);

  static String friendlyMessage(
    int statusCode,
    String? message, {
    String? code,
  }) => AppErrorMessages.fromServer(
    statusCode: statusCode,
    rawMessage: message,
    code: code,
  );

  static void setToken(String? token) {
    final normalized = token?.trim();
    _token = normalized == null || normalized.isEmpty ? null : normalized;
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Uri _uri(String path) {
    final base = Env.apiBaseUrl.trim();

    if (base.isEmpty ||
        !(base.startsWith('http://') || base.startsWith('https://'))) {
      throw ApiException(-1, AppErrorMessages.configurationError);
    }

    final normalizedBase = base.replaceFirst(RegExp(r'/+$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    return Uri.parse('$normalizedBase$normalizedPath');
  }

  static Future<http.Response> _send(
    Future<http.Response> Function(http.Client client) request, {
    required bool retryable,
    ApiCancelToken? cancelToken,
    Duration timeout = const Duration(seconds: 35),
  }) async {
    Object? lastError;
    final maxAttempts = retryable ? 4 : 1;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (cancelToken?.isCancelled ?? false) {
        throw const ApiRequestCancelled();
      }

      final client = http.Client();
      cancelToken?._attach(client);

      try {
        if (cancelToken?.isCancelled ?? false) {
          throw const ApiRequestCancelled();
        }

        return await request(client).timeout(timeout);
      } on ApiRequestCancelled {
        rethrow;
      } catch (error) {
        if (cancelToken?.isCancelled ?? false) {
          throw const ApiRequestCancelled();
        }

        lastError = error;
      } finally {
        cancelToken?._detach(client);
        client.close();
      }

      if (cancelToken?.isCancelled ?? false) {
        throw const ApiRequestCancelled();
      }

      if (retryable && attempt < maxAttempts - 1) {
        await Future<void>.delayed(_delays[attempt]);

        if (cancelToken?.isCancelled ?? false) {
          throw const ApiRequestCancelled();
        }
      }
    }

    final timedOut = lastError is TimeoutException;
    throw ApiException(
      timedOut ? 504 : -1,
      timedOut
          ? AppErrorMessages.requestTimedOut
          : AppErrorMessages.connectionFailure,
    );
  }

  static Future<http.Response> get(String path) {
    return _send(
      (client) => client.get(_uri(path), headers: _headers),
      retryable: true,
    );
  }

  static Future<http.Response> post(String path, [Map<String, dynamic>? body]) {
    return _send(
      (client) => client.post(
        _uri(path),
        headers: _headers,
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
      retryable: false,
    );
  }

  /// POST cancelable para generación del modelo, tanto Chat como Coder.
  static Future<http.Response> postCancelable(
    String path,
    Map<String, dynamic> body,
    ApiCancelToken token, {
    Duration timeout = const Duration(seconds: 35),
  }) {
    return _send(
      (client) =>
          client.post(_uri(path), headers: _headers, body: jsonEncode(body)),
      retryable: false,
      cancelToken: token,
      timeout: timeout,
    );
  }

  /// POST que consume Server-Sent Events para renderizar las respuestas sin esperar al JSON completo.
  /// Cada elemento contiene `event` (nombre SSE) y `data` (JSON del evento).
  static Stream<Map<String, dynamic>> postSse(
    String path,
    Map<String, dynamic> body,
    ApiCancelToken token,
  ) async* {
    if (token.isCancelled) throw const ApiRequestCancelled();

    final client = http.Client();
    token._attach(client);

    try {
      final request = http.Request('POST', _uri(path))
        ..headers.addAll(_headers)
        ..headers['Accept'] = 'text/event-stream'
        ..body = jsonEncode(body);

      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 35));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final bodyText = await response.stream.bytesToString();
        dynamic decoded;
        try {
          decoded = bodyText.isEmpty
              ? <String, dynamic>{}
              : jsonDecode(bodyText);
        } catch (_) {
          decoded = <String, dynamic>{};
        }
        final rawMessage = decoded is Map
            ? '${decoded['error'] ?? decoded['message'] ?? ''}'
            : '';
        final code = decoded is Map ? decoded['code']?.toString() : null;
        throw ApiException(
          response.statusCode,
          AppErrorMessages.fromServer(
            statusCode: response.statusCode,
            rawMessage: rawMessage,
            code: code,
          ),
        );
      }

      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().contains('text/event-stream')) {
        final bodyText = await response.stream.bytesToString();
        dynamic decoded;
        try {
          decoded = jsonDecode(bodyText);
        } catch (_) {
          throw ApiException(502, AppErrorMessages.invalidResponse);
        }
        if (decoded is! Map) {
          throw ApiException(502, AppErrorMessages.invalidResponse);
        }
        yield {'event': 'done', 'data': Map<String, dynamic>.from(decoded)};
        return;
      }

      var eventName = 'message';
      final dataLines = <String>[];

      await for (final line
          in response.stream
              .timeout(const Duration(seconds: 45))
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (token.isCancelled) throw const ApiRequestCancelled();

        if (line.isEmpty) {
          if (dataLines.isNotEmpty) {
            final rawData = dataLines.join('\n');
            dynamic payload;
            try {
              payload = jsonDecode(rawData);
            } catch (_) {
              payload = <String, dynamic>{'raw': rawData};
            }
            yield {
              'event': eventName,
              'data': payload is Map
                  ? Map<String, dynamic>.from(payload)
                  : <String, dynamic>{'value': payload},
            };
          }
          eventName = 'message';
          dataLines.clear();
          continue;
        }

        if (line.startsWith('event:')) {
          eventName = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          dataLines.add(line.substring(5).replaceFirst(RegExp(r'^ '), ''));
        }
      }

      if (dataLines.isNotEmpty) {
        final rawData = dataLines.join('\n');
        dynamic payload;
        try {
          payload = jsonDecode(rawData);
        } catch (_) {
          payload = <String, dynamic>{'raw': rawData};
        }
        yield {
          'event': eventName,
          'data': payload is Map
              ? Map<String, dynamic>.from(payload)
              : <String, dynamic>{'value': payload},
        };
      }
    } on ApiRequestCancelled {
      rethrow;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      if (token.isCancelled) throw const ApiRequestCancelled();
      throw ApiException(504, AppErrorMessages.requestTimedOut);
    } catch (_) {
      if (token.isCancelled) throw const ApiRequestCancelled();
      throw ApiException(-1, AppErrorMessages.connectionFailure);
    } finally {
      token._detach(client);
      client.close();
    }
  }

  static Future<http.Response> put(String path, [Map<String, dynamic>? body]) {
    return _send(
      (client) => client.put(
        _uri(path),
        headers: _headers,
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
      retryable: false,
    );
  }

  static Future<http.Response> patch(
    String path, [
    Map<String, dynamic>? body,
  ]) {
    return _send(
      (client) => client.patch(
        _uri(path),
        headers: _headers,
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
      retryable: false,
    );
  }

  static Future<http.Response> delete(String path) {
    return _send(
      (client) => client.delete(_uri(path), headers: _headers),
      retryable: false,
    );
  }

  static dynamic decode(http.Response response) {
    dynamic data;
    var invalidJson = false;

    try {
      data = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } catch (_) {
      data = <String, dynamic>{};
      invalidJson = response.body.trim().isNotEmpty;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final rawMessage = data is Map
          ? '${data['error'] ?? data['message'] ?? ''}'
          : '';
      final code = data is Map ? data['code']?.toString() : null;
      throw ApiException(
        response.statusCode,
        AppErrorMessages.fromServer(
          statusCode: response.statusCode,
          rawMessage: rawMessage,
          code: code,
        ),
      );
    }

    if (invalidJson) {
      throw ApiException(502, AppErrorMessages.invalidResponse);
    }

    return data;
  }
}
