import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../constants/server_urls.dart';
import 'app_logger.dart';
import 'session_storage.dart';

/// Infers the multipart Content-Type for an attachment from its filename —
/// http.MultipartFile.fromBytes defaults to application/octet-stream
/// without this, which the backend's file processing rejects.
MediaType _mediaTypeFor(String filename) {
  final ext = filename.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return MediaType('image', 'jpeg');
    case 'png':
      return MediaType('image', 'png');
    case 'gif':
      return MediaType('image', 'gif');
    case 'webp':
      return MediaType('image', 'webp');
    case 'bmp':
      return MediaType('image', 'bmp');
    case 'pdf':
      return MediaType('application', 'pdf');
    default:
      return MediaType('application', 'octet-stream');
  }
}

/// Talks to the separate LibreChat backend. No login/token of its own
/// anymore — the backend authenticates by tenant alone, via the
/// `X-Tenant-Id` header (see [_headers]), so every call just needs that
/// plus the spoofed User-Agent.
class LibreChatService {
  LibreChatService._();

  static const _browserUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  static Future<Map<String, String>> _headers() async {
    final userId = await SessionStorage().readUserId();
    return {
      'User-Agent': _browserUserAgent,
      'X-Tenant-Id': ServerUrls.tenant,
      if (userId != null) 'X-User-Id': userId,
    };
  }

  static Future<List<Map<String, dynamic>>> fetchAgents() async {
    final response = await http.get(
        Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatAgents}'),
        headers: await _headers());
    AppLogger.i('LibreChat',
        'fetchAgents -> ${response.statusCode}: ${redactedPreview(response.body)}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Failed to load agents (${response.statusCode}): ${response.body}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'];
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> fetchAgentById(String id) async {
    final response = await http.get(
        Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatAgents}$id'),
        headers: await _headers());
    AppLogger.i('LibreChat',
        'fetchAgentById($id) -> ${response.statusCode}: ${redactedPreview(response.body)}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Failed to load agent (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> fetchConversations() async {
    final response = await http.get(
        Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatConvos}'),
        headers: await _headers());
    AppLogger.i('LibreChat',
        'fetchConversations -> ${response.statusCode}: ${redactedPreview(response.body)}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Failed to load conversations (${response.statusCode}): ${response.body}');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['conversations'];
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> fetchMessages(
      String conversationId) async {
    final response = await http.get(
      Uri.parse(
          '${ServerUrls.librechatURL}${ServerUrls.librechatMessages}$conversationId'),
      headers: await _headers(),
    );
    AppLogger.i('LibreChat',
        'fetchMessages($conversationId) -> ${response.statusCode}: ${redactedPreview(response.body)}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Failed to load messages (${response.statusCode}): ${response.body}');
    }
    final data = jsonDecode(response.body);
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }

  static Future<String?> _gosureToken() => SessionStorage().readAccessToken();

 
  static Future<Map<String, dynamic>> uploadAttachment({
    required String agentId,
    required List<int> bytes,
    required String filename,
    required String fileId,
    int? width,
    int? height,
  }) async {
    final fields = {
      'file_id': fileId,
      'endpoint': 'agents',
      'agent_id': agentId,
      'message_file': 'true',
      if (width != null) 'width': width.toString(),
      if (height != null) 'height': height.toString(),
    };
    fields.forEach((key, value) =>
        AppLogger.i('LibreChat', 'uploadAttachment($filename) form field: $key=$value'));
    AppLogger.i('LibreChat',
        'uploadAttachment($filename) form field: file=<${bytes.length} bytes>');

    final headers = await _headers();
    AppLogger.i('LibreChat', 'uploadAttachment($filename) headers: $headers');

    final request = http.MultipartRequest('POST',
        Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatFilesImages}'))
      ..headers.addAll(headers)
      ..fields.addAll(fields)
      ..files.add(http.MultipartFile.fromBytes('file', bytes,
          filename: filename, contentType: _mediaTypeFor(filename)));

    AppLogger.i('LibreChat',
        'uploadAttachment($filename) sending: contentLength=${request.contentLength} contentType=${request.headers['content-type']}');

    final response = await http.Response.fromStream(await request.send());
    AppLogger.i('LibreChat',
        'uploadAttachment($filename) -> ${response.statusCode}: ${redactedPreview(response.body)}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Failed to upload attachment (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> sendChatMessage({
    required String agentId,
    required String text,
    required String messageId,
    required String parentMessageId,
    String? conversationId,
    List<Map<String, dynamic>>? files,
  }) async {
    AppLogger.i('LibreChat',
        'sendChatMessage request: agentId=$agentId conversationId=$conversationId textLen=${text.length} files=${files?.length ?? 0}');
    final gosureToken = await _gosureToken();
    final response = await http.post(
      Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatAgentChat}'),
      headers: {
        ...await _headers(),
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
        if (files != null && files.isNotEmpty) 'files': files,
      }),
    );
    AppLogger.i('LibreChat',
        'sendChatMessage -> ${response.statusCode}: ${redactedPreview(response.body)}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Failed to send message (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<http.StreamedResponse> _openStream(
      http.Client client, String conversationId, String? gosureToken) async {
    final request = http.Request(
      'GET',
      Uri.parse(
          '${ServerUrls.librechatURL}${ServerUrls.librechatAgentChatStream}$conversationId'),
    );
    request.headers.addAll({
      ...await _headers(),
      'Accept': 'text/event-stream',
      if (gosureToken != null) 'X-Gosure-Token': gosureToken,
    });
    return client.send(request);
  }

  static Stream<Map<String, dynamic>> streamChat(String conversationId) async* {
    AppLogger.i('LibreChat', 'streamChat($conversationId) opening');
    final gosureToken = await _gosureToken();
    final client = http.Client();
    final response = await _openStream(client, conversationId, gosureToken);
    AppLogger.i('LibreChat',
        'streamChat($conversationId) -> ${response.statusCode}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      client.close();
      throw Exception('Failed to open chat stream (${response.statusCode})');
    }

    var eventCount = 0;
    try {
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data: ')) continue;
        final jsonStr = line.substring(6);
        if (jsonStr.isEmpty) continue;
        final event = jsonDecode(jsonStr) as Map<String, dynamic>;
        eventCount++;
        if (event['final'] == true) {
          AppLogger.i('LibreChat',
              'streamChat($conversationId) final event after $eventCount events');
        }
        yield event;
      }
    } finally {
      AppLogger.i('LibreChat',
          'streamChat($conversationId) closed after $eventCount events');
      client.close();
    }
  }
}
