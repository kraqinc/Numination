import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'env.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
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

  static void setToken(String? token) {
    final normalized = token?.trim();
    _token = normalized == null || normalized.isEmpty
        ? null
        : normalized;
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Uri _uri(String path) {
    final base = Env.apiBaseUrl.trim();

    if (base.isEmpty ||
        !(base.startsWith('http://') ||
            base.startsWith('https://'))) {
      throw const ApiException(
        -1,
        'API_BASE_URL no está configurado correctamente en .env.',
      );
    }

    final normalizedBase =
        base.replaceFirst(RegExp(r'/+$'), '');
    final normalizedPath =
        path.startsWith('/') ? path : '/$path';

    return Uri.parse('$normalizedBase$normalizedPath');
  }

  static Future<http.Response> _send(
    Future<http.Response> Function(http.Client client) request, {
    required bool retryable,
    ApiCancelToken? cancelToken,
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

        return await request(client).timeout(
          const Duration(seconds: 35),
        );
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

    throw ApiException(
      -1,
      retryable
          ? 'No se pudo conectar con Numination. Detalle: $lastError'
          : 'La solicitud no pudo completarse. Revisa tu conexión.',
    );
  }

  static Future<http.Response> get(String path) {
    return _send(
      (client) => client.get(
        _uri(path),
        headers: _headers,
      ),
      retryable: true,
    );
  }

  static Future<http.Response> post(
    String path, [
    Map<String, dynamic>? body,
  ]) {
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
    ApiCancelToken token,
  ) {
    return _send(
      (client) => client.post(
        _uri(path),
        headers: _headers,
        body: jsonEncode(body),
      ),
      retryable: false,
      cancelToken: token,
    );
  }

  static Future<http.Response> put(
    String path, [
    Map<String, dynamic>? body,
  ]) {
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
      (client) => client.delete(
        _uri(path),
        headers: _headers,
      ),
      retryable: false,
    );
  }

  static dynamic decode(http.Response response) {
    dynamic data;

    try {
      data = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } catch (_) {
      data = <String, dynamic>{};
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      final message = data is Map
          ? '${data['error'] ?? data['message'] ?? 'Error del servidor'}'
          : 'Error ${response.statusCode}';

      throw ApiException(response.statusCode, message);
    }

    return data;
  }
}
