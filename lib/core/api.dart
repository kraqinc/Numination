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
  static const _delays = [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)];
  static void setToken(String? token) => _token = token;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Uri _uri(String path) => Uri.parse('${Env.apiBaseUrl.replaceAll(RegExp(r'/$'), '')}$path');

  static Future<http.Response> _send(Future<http.Response> Function() request) async {
    Object? lastError;
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final response = await request().timeout(const Duration(seconds: 35));
        return response;
      } on TimeoutException catch (e) {
        lastError = e;
      } catch (e) {
        lastError = e;
      }
      if (attempt < 3) await Future<void>.delayed(_delays[attempt]);
    }
    throw ApiException(-1, 'No se pudo conectar con Numination. Revisa tu conexión e inténtalo de nuevo.\nDetalle: $lastError');
  }

  static Future<http.Response> get(String path) => _send(() => http.get(_uri(path), headers: _headers));
  static Future<http.Response> post(String path, [Map<String, dynamic>? body]) => _send(() => http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? <String, dynamic>{})));
  static Future<http.Response> put(String path, [Map<String, dynamic>? body]) => _send(() => http.put(_uri(path), headers: _headers, body: jsonEncode(body ?? <String, dynamic>{})));
  static Future<http.Response> delete(String path) => _send(() => http.delete(_uri(path), headers: _headers));

  static dynamic decode(http.Response response) {
    dynamic data;
    try { data = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body); } catch (_) { data = <String, dynamic>{}; }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map ? '${data['error'] ?? data['message'] ?? 'Error del servidor'}' : 'Error ${response.statusCode}';
      throw ApiException(response.statusCode, message);
    }
    return data;
  }
}
