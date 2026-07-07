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

/// Thin HTTP wrapper shared by every Api*Repository implementation (see
/// repositories/pro_repository.dart etc.) so they don't each reimplement
/// headers, JSON encoding, the access token, and error handling.
///
/// Usage once you're ready to swap a Static*Repository for a real backend:
///
/// ```dart
/// final api = ApiClient(baseUrl: 'https://api.example.com');
/// api.setAccessToken(token); // after login, or on app start if restored
///
/// class ApiProRepository implements ProRepository {
///   final ApiClient _api;
///   ApiProRepository(this._api);
///
///   @override
///   Future<Pro?> getById(String id) async {
///     final json = await _api.get('/pros/$id');
///     return json == null ? null : Pro.fromJson(json);
///   }
/// }
/// ```
class ApiClient {
  final String baseUrl;
  final http.Client _client;
  String? _accessToken;

  ApiClient({required this.baseUrl, http.Client? client}) : _client = client ?? http.Client();

  /// Call after login (or on app start, once a saved token is restored) so
  /// every subsequent request is authenticated. Pass null to log out.
  void setAccessToken(String? token) {
    _accessToken = token;
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final response = await _client.get(_uri(path, query), headers: _headers());
    return _decode(response);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final response = await _client.post(_uri(path), headers: _headers(), body: _encode(body));
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
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  dynamic _decode(http.Response response) {
    final status = response.statusCode;
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (status < 200 || status >= 300) {
      final message = (body is Map && body['message'] is String) ? body['message'] as String : (response.reasonPhrase ?? 'Request failed');
      throw ApiException(status, message);
    }
    return body;
  }

  void close() => _client.close();
}
