import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/server_urls.dart';
import 'app_logger.dart';
import 'session_storage.dart';

/// Talks to the separate LibreChat backend. No login/token of its own
/// anymore — the backend authenticates by tenant alone, via the
/// `X-Tenant-Id` header (see [_headers]), so every call just needs that
/// plus the spoofed User-Agent.
class LibreChatService {
  LibreChatService._();

  
  static const _browserUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  static Map<String, String> _headers() => {
        'User-Agent': _browserUserAgent,
        'X-Tenant-Id': ServerUrls.tenant,
      };

  static Future<List<Map<String, dynamic>>> fetchAgents() async {
    final response = await http.get(Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatAgents}'), headers: _headers());
    AppLogger.i('LibreChat', 'fetchAgents -> ${response.statusCode}: ${redactedPreview(response.body)}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load agents (${response.statusCode}): ${response.body}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'];
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }


  static Future<Map<String, dynamic>> fetchAgentById(String id) async {
    final response =
        await http.get(Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatAgents}$id'), headers: _headers());
    AppLogger.i('LibreChat', 'fetchAgentById($id) -> ${response.statusCode}: ${redactedPreview(response.body)}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load agent (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }


  static Future<List<Map<String, dynamic>>> fetchConversations() async {
    final response = await http.get(Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatConvos}'), headers: _headers());
    AppLogger.i('LibreChat', 'fetchConversations -> ${response.statusCode}: ${redactedPreview(response.body)}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load conversations (${response.statusCode}): ${response.body}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['conversations'];
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }


  static Future<List<Map<String, dynamic>>> fetchMessages(String conversationId) async {
    final response = await http.get(
      Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatMessages}$conversationId'),
      headers: _headers(),
    );
    AppLogger.i('LibreChat', 'fetchMessages($conversationId) -> ${response.statusCode}: ${redactedPreview(response.body)}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load messages (${response.statusCode}): ${response.body}');
    }
    final data = jsonDecode(response.body);
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }

 
  static Future<String?> _gosureToken() => SessionStorage().readAccessToken();


  static Future<Map<String, dynamic>> sendChatMessage({
    required String agentId,
    required String text,
    required String messageId,
    required String parentMessageId,
    String? conversationId,
  }) async {
    final gosureToken = await _gosureToken();
    final response = await http.post(
      Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatAgentChat}'),
      headers: {
        ..._headers(),
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
    );
    AppLogger.i('LibreChat', 'sendChatMessage -> ${response.statusCode}: ${redactedPreview(response.body)}');
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
      ..._headers(),
      'Accept': 'text/event-stream',
      if (gosureToken != null) 'X-Gosure-Token': gosureToken,
    });
    return client.send(request);
  }

 
  static Stream<Map<String, dynamic>> streamChat(String conversationId) async* {
    final gosureToken = await _gosureToken();
    final client = http.Client();
    final response = await _openStream(client, conversationId, gosureToken);

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
