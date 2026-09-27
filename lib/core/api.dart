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

class ApiClient {
  static String? _token;

  static const _delays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

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
      throw const ApiException(
        -1,
        'Numination no tiene configurado API_BASE_URL correctamente. Revisa tu .env.',
      );
    }

    final normalizedBase = base.replaceFirst(RegExp(r'/+$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    return Uri.parse('$normalizedBase$normalizedPath');
  }

  static Future<http.Response> _send(
    Future<http.Response> Function() request, {
    required bool retryable,
  }) async {
    Object? lastError;

    final maxAttempts = retryable ? 4 : 1;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await request().timeout(const Duration(seconds: 35));
      } catch (e) {
        lastError = e;
      }

      if (retryable && attempt < maxAttempts - 1) {
        await Future<void>.delayed(_delays[attempt]);
      }
    }

    throw ApiException(
      -1,
      retryable
          ? 'No se pudo conectar con Numination. Revisa tu conexión. Detalle: $lastError'
          : 'La solicitud no pudo completarse. Revisa tu conexión e inténtalo de nuevo.',
    );
  }

  // GET puede reintentarse porque es una operación de lectura.
  static Future<http.Response> get(String path) =>
      _send(
        () => http.get(_uri(path), headers: _headers),
        retryable: true,
      );

  // Las operaciones mutables NO se reintentan automáticamente.
  // Así evitamos duplicar creaciones, cambios, eliminaciones o consumo.
  static Future<http.Response> post(
    String path, [
    Map<String, dynamic>? body,
  ]) =>
      _send(
        () => http.post(
          _uri(path),
          headers: _headers,
          body: jsonEncode(body ?? <String, dynamic>{}),
        ),
        retryable: false,
      );

  static Future<http.Response> put(
    String path, [
    Map<String, dynamic>? body,
  ]) =>
      _send(
        () => http.put(
          _uri(path),
          headers: _headers,
          body: jsonEncode(body ?? <String, dynamic>{}),
        ),
        retryable: false,
      );

  static Future<http.Response> patch(
    String path, [
    Map<String, dynamic>? body,
  ]) =>
      _send(
        () => http.patch(
          _uri(path),
          headers: _headers,
          body: jsonEncode(body ?? <String, dynamic>{}),
        ),
        retryable: false,
      );

  static Future<http.Response> delete(String path) =>
      _send(
        () => http.delete(_uri(path), headers: _headers),
        retryable: false,
      );

  static dynamic decode(http.Response response) {
    dynamic data;

    try {
      data = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } catch (_) {
      data = <String, dynamic>{};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map
          ? '${data['error'] ?? data['message'] ?? 'Error del servidor'}'
          : 'Error ${response.statusCode}';

      throw ApiException(response.statusCode, message);
    }

    return data;
  }
}
