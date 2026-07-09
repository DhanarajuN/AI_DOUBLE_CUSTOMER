import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/server_urls.dart';

/// Talks to the separate LibreChat backend: a silent login on app start
/// (see [loginAndCacheToken], fired from [SplashView] with no UI of its
/// own) plus authenticated reads like [fetchAgents] used by
/// widgets/new_request_sheet.dart.
class LibreChatService {
  LibreChatService._();

  static const tokenKey = 'libreToken';
  static const refreshTokenKey = 'libreRefreshToken';

  static const _email = 'ksreekar407@gmail.com';
  static const _password = 'padma1314';

  // The backend's bot-detection (in front of /api/agents at least) rejects
  // requests without a browser-shaped User-Agent — Dart's default (or none
  // at all) gets a 200 response with an SSE-framed "Illegal request" body
  // instead of a normal error, so every call needs to spoof one.
  static const _browserUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  static Future<void> loginAndCacheToken() async {
    try {
      final response = await http.post(
        Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatLogin}'),
        headers: {'Content-Type': 'application/json', 'User-Agent': _browserUserAgent},
        body: jsonEncode({'email': _email, 'password': _password}),
      );
      debugPrint('[LibreChat] login -> ${response.statusCode}: ${response.body}');
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final token = json['token'] as String?;
      if (token == null) {
        debugPrint('[LibreChat] login response had no "token" field');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(tokenKey, token);

      // The login response sets the refresh token as a cookie (not in the
      // JSON body) — later authenticated calls (e.g. fetchAgents) need to
      // replay it alongside the bearer token.
      final setCookie = response.headers['set-cookie'];
      final refreshToken = setCookie == null ? null : RegExp(r'refreshToken=([^;]+)').firstMatch(setCookie)?.group(1);
      if (refreshToken != null) {
        await prefs.setString(refreshTokenKey, refreshToken);
      } else {
        debugPrint('[LibreChat] no refreshToken cookie in login response (set-cookie header: $setCookie)');
      }
    } catch (e) {
      debugPrint('[LibreChat] login failed: $e');
    }
  }

  static Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);
    final refreshToken = prefs.getString(refreshTokenKey);
    return {
      'User-Agent': _browserUserAgent,
      if (token != null) 'Authorization': 'Bearer $token',
      if (refreshToken != null) 'Cookie': 'refreshToken=$refreshToken; token_provider=librechat',
    };
  }

  /// Fetches the agent list for the "New request" sheet. Returns the raw
  /// `data` array from the response — each entry is expected to carry at
  /// least `id`, `name` and `description`.
  static Future<List<Map<String, dynamic>>> fetchAgents() async {
    final response = await http.get(
      Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatAgents}'),
      headers: await _authHeaders(),
    );
    debugPrint('[LibreChat] fetchAgents -> ${response.statusCode}: ${response.body}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load agents (${response.statusCode}): ${response.body}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'];
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }

  /// Fetches full detail for one agent (by its `id`, e.g. `agent_xxx`) —
  /// used to open the agent's chat page with its real name/avatar and
  /// `conversation_starters`.
  static Future<Map<String, dynamic>> fetchAgentById(String id) async {
    final response = await http.get(
      Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatAgents}$id'),
      headers: await _authHeaders(),
    );
    debugPrint('[LibreChat] fetchAgentById($id) -> ${response.statusCode}: ${response.body}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load agent (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
