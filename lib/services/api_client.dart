import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thrown when an API call returns a non-2xx response.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin HTTP wrapper shared by every repository so they don't each
/// reimplement headers, JSON encoding, the access token, and error handling.
class ApiClient {
  final String baseUrl;
  final String? tenant;
  final http.Client _client;
  String? _accessToken;

  ApiClient({required this.baseUrl, this.tenant, http.Client? client}) : _client = client ?? http.Client();

  /// Call after login (or on app start, once a saved token is restored) so
  /// every subsequent request is authenticated. Pass null to log out.
  void setAccessToken(String? token) {
    _accessToken = token;
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final response = await _client.get(_uri(path, query), headers: _headers());
    return _decode(response);
  }

  Future<dynamic> post(String path, {Object? body, Map<String, String>? query}) async {
    final response = await _client.post(_uri(path, query), headers: _headers(), body: _encode(body));
    return _decode(response);
  }

  Future<dynamic> put(String path, {Object? body}) async {
    final response = await _client.put(_uri(path), headers: _headers(), body: _encode(body));
    return _decode(response);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  String? _encode(Object? body) => body == null ? null : jsonEncode(body);

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (tenant != null) 'X-Tenant': tenant!,
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  dynamic _decode(http.Response response) {
    final status = response.statusCode;
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (status < 200 || status >= 300) {
      String? stringField(String key) => body is Map && body[key] is String ? body[key] as String : null;
      final serverMessage = stringField('msg') ?? stringField('message');
      final reason = response.reasonPhrase;
      // reasonPhrase is often an empty string (not null) on HTTP/2 responses,
      // which have no reason phrase — so a plain `??` fallback misses it and
      // leaves the error with no visible text.
      final message = (serverMessage != null && serverMessage.isNotEmpty)
          ? serverMessage
          : (reason != null && reason.isNotEmpty)
              ? reason
              : 'Request failed with status $status';
      throw ApiException(status, message);
    }
    return body;
  }

  void close() => _client.close();
}
