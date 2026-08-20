import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_logger.dart';

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

  /// Fired on a 401 from any call NOT marked `silent` — the token it was
  /// sent with is no longer valid server-side (expired, revoked), something
  /// no client code tracks proactively today. Left unhandled, this looked
  /// exactly like "that resource doesn't exist" to callers, with no way to
  /// recover except force-quitting and reopening the app. AuthRepository
  /// wires this to a real sign-out + return-to-login so a stale session
  /// recovers on its own.
  ///
  /// Pass `silent: true` on a call that is a background/best-effort
  /// side-fetch the user never sees waiting (a stale-cache refresh, a
  /// fire-and-forget enrichment after login already succeeded) — a 401
  /// there is not evidence the session is actually dead, and must not be
  /// able to force a perfectly valid, just-signed-in user straight back out.
  /// Every call that blocks a screen the user is actually looking at should
  /// keep the default (unauthorized = really log them out).
  void Function()? onUnauthorized;

  ApiClient({required this.baseUrl, this.tenant, http.Client? client})
      : _client = client ?? http.Client();

  /// Call after login (or on app start, once a saved token is restored) so
  /// every subsequent request is authenticated. Pass null to log out.
  void setAccessToken(String? token) {
    _accessToken = token;
  }

  String? get accessToken => _accessToken;

  Future<dynamic> get(String path,
      {Map<String, String>? query, bool silent = false}) {
    return _request(
        'GET', path, () => _client.get(_uri(path, query), headers: _headers()),
        silent: silent);
  }

  Future<dynamic> post(String path,
      {Object? body, Map<String, String>? query, bool silent = false}) {
    return _request(
      'POST',
      path,
      () => _client.post(_uri(path, query),
          headers: _headers(), body: _encode(body)),
      body: body,
      silent: silent,
    );
  }

  Future<dynamic> put(String path, {Object? body, bool silent = false}) {
    return _request('PUT', path,
        () => _client.put(_uri(path), headers: _headers(), body: _encode(body)),
        body: body, silent: silent);
  }

  Future<dynamic> _request(
      String method, String path, Future<http.Response> Function() send,
      {Object? body, bool silent = false}) async {
    final stopwatch = Stopwatch()..start();
    AppLogger.i('ApiClient',
        '$method $path${body == null ? '' : ' body=${jsonEncode(redactJson(body))}'}');
    try {
      final response = await send();
      final result = _decode(response, silent: silent);
      AppLogger.i('ApiClient',
          '$method $path -> ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms');
      return result;
    } catch (e) {
      AppLogger.e('ApiClient',
          '$method $path failed after ${stopwatch.elapsedMilliseconds}ms', e);
      rethrow;
    }
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

  dynamic _decode(http.Response response, {bool silent = false}) {
    final status = response.statusCode;
    final body = response.body.isEmpty ? null : jsonDecode(response.body);
    if (status == 401 && !silent) onUnauthorized?.call();
    if (status < 200 || status >= 300) {
      String? stringField(String key) =>
          body is Map && body[key] is String ? body[key] as String : null;
      String? listField(String key) => body is Map && body[key] is List
          ? (body[key] as List).map((e) => e.toString()).join(', ')
          : null;
      final serverMessage =
          stringField('msg') ?? stringField('message') ?? listField('messages');
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
