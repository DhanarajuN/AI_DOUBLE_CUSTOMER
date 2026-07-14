import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/server_urls.dart';
import 'session_storage.dart';

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

  /// Issues one request via [doRequest] (which receives fresh auth headers
  /// each call) and, if the response is a 401 (expired/malformed/missing
  /// JWT), re-authenticates once via [loginAndCacheToken] and retries with
  /// the refreshed token — so a stale cached token self-heals instead of
  /// surfacing as an error to the UI.
  static Future<http.Response> _requestWithRetry(
    Future<http.Response> Function(Map<String, String> headers) doRequest,
  ) async {
    var response = await doRequest(await _authHeaders());
    if (response.statusCode == 401) {
      debugPrint('[LibreChat] got 401, re-authenticating and retrying: ${response.body}');
      await loginAndCacheToken();
      response = await doRequest(await _authHeaders());
    }
    return response;
  }

  /// Fetches the agent list for the "New request" sheet. Returns the raw
  /// `data` array from the response — each entry is expected to carry at
  /// least `id`, `name` and `description`.
  static Future<List<Map<String, dynamic>>> fetchAgents() async {
    final response = await _requestWithRetry(
      (headers) => http.get(Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatAgents}'), headers: headers),
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
    final response = await _requestWithRetry(
      (headers) => http.get(Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatAgents}$id'), headers: headers),
    );
    debugPrint('[LibreChat] fetchAgentById($id) -> ${response.statusCode}: ${response.body}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load agent (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Fetches the signed-in user's past conversations for the chat list.
  /// Returns the raw `conversations` array (first page only — the response
  /// also carries a `nextCursor` for pagination, not consumed yet). Each
  /// entry has `conversationId`, `agent_id`, `title`, `updatedAt`, but no
  /// agent name/avatar or message preview.
  static Future<List<Map<String, dynamic>>> fetchConversations() async {
    final response = await _requestWithRetry(
      (headers) => http.get(Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatConvos}'), headers: headers),
    );
    debugPrint('[LibreChat] fetchConversations -> ${response.statusCode}: ${response.body}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load conversations (${response.statusCode}): ${response.body}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['conversations'];
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }

  /// Fetches the full message history for one conversation, oldest first.
  /// Each entry has `messageId`/`parentMessageId`, `isCreatedByUser`, and
  /// either `text` (user messages) or a `content` array of `{type, text}`
  /// items (agent replies) — same shape as streamChat's final event.
  static Future<List<Map<String, dynamic>>> fetchMessages(String conversationId) async {
    final response = await _requestWithRetry(
      (headers) => http.get(Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatMessages}$conversationId'), headers: headers),
    );
    debugPrint('[LibreChat] fetchMessages($conversationId) -> ${response.statusCode}: ${response.body}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load messages (${response.statusCode}): ${response.body}');
    }
    final data = jsonDecode(response.body);
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }

  /// The AI Double app's own session accessToken (a different auth system
  /// from LibreChat's), sent as `X-Gosure-Token` so the backend can
  /// correlate a chat request/stream back to the GoSure user.
  static Future<String?> _gosureToken() => SessionStorage().readAccessToken();

  /// Sends one message to an agent. Returns the immediate ack
  /// `{streamId, conversationId, status}` — the actual reply arrives over
  /// [streamChat], not in this response. Pass `conversationId: null` and
  /// `parentMessageId: "00000000-0000-0000-0000-000000000000"` for the
  /// first message in a new conversation; for later turns, pass the
  /// established conversationId and the previous reply's messageId.
  static Future<Map<String, dynamic>> sendChatMessage({
    required String agentId,
    required String text,
    required String messageId,
    required String parentMessageId,
    String? conversationId,
  }) async {
    final gosureToken = await _gosureToken();
    final response = await _requestWithRetry(
      (headers) => http.post(
        Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatAgentChat}'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
          if (gosureToken != null) 'X-Gosure-Token': gosureToken,
        },
        body: jsonEncode({
          'endpoint': 'agents',
          'agent_id': agentId,
          'text': text,
          'messageId': messageId,
          'parentMessageId': parentMessageId,
          'conversationId': conversationId,
          'isContinued': false,
        }),
      ),
    );
    debugPrint('[LibreChat] sendChatMessage -> ${response.statusCode}: ${response.body}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to send message (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<http.StreamedResponse> _openStream(http.Client client, String conversationId, String? gosureToken) async {
    final request = http.Request(
      'GET',
      Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatAgentChatStream}$conversationId'),
    );
    request.headers.addAll({
      ...await _authHeaders(),
      'Accept': 'text/event-stream',
      if (gosureToken != null) 'X-Gosure-Token': gosureToken,
    });
    return client.send(request);
  }

  /// Opens the SSE stream for a conversation (keyed by the `streamId`
  /// returned from [sendChatMessage], which in practice equals
  /// `conversationId`) and yields each event's decoded JSON payload as it
  /// arrives — `on_message_delta` events carry incremental reply text, and
  /// the event with `final: true` carries the complete `responseMessage`.
  /// Re-authenticates once and retries if the initial connection gets a 401.
  static Stream<Map<String, dynamic>> streamChat(String conversationId) async* {
    final gosureToken = await _gosureToken();
    var client = http.Client();
    var response = await _openStream(client, conversationId, gosureToken);

    if (response.statusCode == 401) {
      debugPrint('[LibreChat] stream got 401, re-authenticating and retrying');
      client.close();
      await loginAndCacheToken();
      client = http.Client();
      response = await _openStream(client, conversationId, gosureToken);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      client.close();
      throw Exception('Failed to open chat stream (${response.statusCode})');
    }

    try {
      await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (!line.startsWith('data: ')) continue;
        final jsonStr = line.substring(6);
        if (jsonStr.isEmpty) continue;
        yield jsonDecode(jsonStr) as Map<String, dynamic>;
      }
    } finally {
      client.close();
    }
  }
}
