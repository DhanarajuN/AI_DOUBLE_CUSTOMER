import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../constants/server_urls.dart';
import 'app_logger.dart';
import 'session_storage.dart';

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

class LibreChatService {
  LibreChatService._();

  static const _browserUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  static Future<Map<String, String>> _headers() async {
    final userId = await SessionStorage().readUserId();
    final gosureToken = await _gosureToken();
    return {
      'User-Agent': _browserUserAgent,
      'X-Tenant-Id': ServerUrls.tenant,
      if (userId != null) 'X-User-Id': userId,
      if (gosureToken != null) 'X-Gosure-Token': gosureToken,
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

  // Batch message counts for the chat list's unread badges — one request for every
  // visible conversation instead of one per row. Stock GET /api/convos (above) has no
  // message-count field, so this is a small Gosure-side addition alongside it.
  static Future<Map<String, int>> fetchConversationCounts(
      List<String> conversationIds) async {
    if (conversationIds.isEmpty) return {};
    final response = await http.post(
      Uri.parse(
          '${ServerUrls.librechatURL}${ServerUrls.gosureConvoEvents}counts'),
      headers: {...await _headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({'conversationIds': conversationIds}),
    );
    AppLogger.i('LibreChat',
        'fetchConversationCounts(${conversationIds.length} ids) -> ${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Best-effort: a failed count fetch shouldn't block the chat list from showing.
      return {};
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final counts = json['counts'] as Map<String, dynamic>?;
    if (counts == null) return {};
    return counts.map((key, value) => MapEntry(key, (value as num).toInt()));
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

  static Future<Map<String, dynamic>> uploadToGosureAttachments({
    required List<int> bytes,
    required String filename,
  }) async {
    final token = await _gosureToken();
    final headers = {
      if (token != null) 'Authorization': 'Bearer $token',
    };
    AppLogger.i(
        'LibreChat', 'uploadToGosureAttachments($filename) headers: $headers');

    final request = http.MultipartRequest('POST',
        Uri.parse('${ServerUrls.baseUrl}${ServerUrls.attachmentsUpload}'))
      ..headers.addAll(headers)
      ..files.add(http.MultipartFile.fromBytes('attachment', bytes,
          filename: filename, contentType: _mediaTypeFor(filename)));

    final response = await http.Response.fromStream(await request.send());
    AppLogger.i('LibreChat',
        'uploadToGosureAttachments($filename) -> ${response.statusCode}: ${redactedPreview(response.body)}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Failed to upload attachment (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Uint8List> downloadAttachment(String fileId) async {
    final token = await _gosureToken();
    final response = await http.get(
      Uri.parse(
          '${ServerUrls.baseUrl}${ServerUrls.attachmentsDownload}?id=$fileId'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    AppLogger.i('LibreChat',
        'downloadAttachment($fileId) -> ${response.statusCode}: ${response.bodyBytes.length} bytes');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to download attachment (${response.statusCode})');
    }
    return response.bodyBytes;
  }

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
    fields.forEach((key, value) => AppLogger.i(
        'LibreChat', 'uploadAttachment($filename) form field: $key=$value'));
    AppLogger.i('LibreChat',
        'uploadAttachment($filename) form field: file=<${bytes.length} bytes>');

    final headers = await _headers();
    AppLogger.i('LibreChat', 'uploadAttachment($filename) headers: $headers');

    final request = http.MultipartRequest(
        'POST',
        Uri.parse(
            '${ServerUrls.librechatURL}${ServerUrls.librechatFilesImages}'))
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
    String? businessId,
    String? senderName,
    List<Map<String, dynamic>>? files,
  }) async {
    AppLogger.i('LibreChat',
        'sendChatMessage request: agentId=$agentId conversationId=$conversationId businessId=$businessId textLen=${text.length} files=${files?.length ?? 0}');
    final response = await http.post(
      Uri.parse('${ServerUrls.librechatURL}${ServerUrls.librechatAgentChat}'),
      headers: {
        ...await _headers(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'endpoint': 'agents',
        'agent_id': agentId,
        'text': text,
        'messageId': messageId,
        'parentMessageId': parentMessageId,
        'conversationId': conversationId,
        'businessId': businessId,
        if (senderName != null && senderName.isNotEmpty)
          'senderName': senderName,
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

  static Future<List<String>> suggestReplies({
    required String conversationId,
    required String lastUserMessage,
    String? agentDescription,
  }) async {
    final response = await http.post(
      Uri.parse(
          '${ServerUrls.librechatURL}${ServerUrls.librechatSuggestReplies}'),
      headers: {
        ...await _headers(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'conversationId': conversationId,
        'lastUserMessage': lastUserMessage,
        'agentDescription': agentDescription,
      }),
    );
    AppLogger.i('LibreChat',
        'suggestReplies -> ${response.statusCode}: ${redactedPreview(response.body)}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Failed to fetch suggested replies (${response.statusCode}): ${response.body}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final replies = decoded['replies'] as List?;
    return (replies ?? const []).map((e) => e.toString()).toList();
  }

  static Future<http.StreamedResponse> _openStream(
      http.Client client, String conversationId) async {
    final request = http.Request(
      'GET',
      Uri.parse(
          '${ServerUrls.librechatURL}${ServerUrls.librechatAgentChatStream}$conversationId'),
    );
    request.headers.addAll({
      ...await _headers(),
      'Accept': 'text/event-stream',
    });
    return client.send(request);
  }

  // Shared plumbing for both streams below. Deliberately NOT an `async*` generator:
  // cancelling a subscription over an async* function only unwinds the generator (and
  // runs its `finally`/closes the client) the NEXT time it reaches an await/yield point
  // — if the server has nothing new to send, that doesn't happen until the next 30s
  // heartbeat, so the real HTTP connection stays open long after the app considers it
  // "closed". Reopening streams (new turns, reopening a conversation) faster than that
  // leaks connections until the browser's per-origin connection limit is hit, at which
  // point every request — including a plain fetch — queues forever behind the leaked
  // ones. A StreamController with an explicit onCancel that force-closes the client
  // fixes this: cancellation now tears down the underlying socket immediately.
  static Stream<Map<String, dynamic>> _openEventStream(
    String label,
    Future<http.StreamedResponse> Function(http.Client) send,
  ) {
    http.Client? client;
    StreamSubscription<String>? lineSub;
    late final StreamController<Map<String, dynamic>> controller;
    var eventCount = 0;

    Future<void> start() async {
      final c = http.Client();
      client = c;
      AppLogger.i('LibreChat', '$label opening');
      try {
        final response = await send(c);
        AppLogger.i('LibreChat', '$label -> ${response.statusCode}');

        if (response.statusCode < 200 || response.statusCode >= 300) {
          controller.addError(
              Exception('Failed to open stream (${response.statusCode})'));
          await controller.close();
          c.close();
          return;
        }

        lineSub = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                if (!line.startsWith('data: ')) return;
                final jsonStr = line.substring(6);
                if (jsonStr.isEmpty) return;
                eventCount++;
                controller.add(jsonDecode(jsonStr) as Map<String, dynamic>);
              },
              onError: (Object e) => controller.addError(e),
              onDone: () {
                AppLogger.i(
                    'LibreChat', '$label closed after $eventCount events');
                controller.close();
              },
            );
      } catch (e) {
        controller.addError(e);
        await controller.close();
      }
    }

    controller = StreamController<Map<String, dynamic>>(
      onListen: start,
      onCancel: () {
        AppLogger.i(
            'LibreChat', '$label cancelled, closing connection immediately');
        lineSub?.cancel();
        client?.close();
      },
    );
    return controller.stream;
  }

  static Stream<Map<String, dynamic>> streamChat(String conversationId) {
    return _openEventStream(
      'streamChat($conversationId)',
      (client) => _openStream(client, conversationId),
    );
  }

  static Future<http.StreamedResponse> _openEventsStream(
      http.Client client, String conversationId) async {
    final request = http.Request(
      'GET',
      Uri.parse(
          '${ServerUrls.librechatURL}${ServerUrls.gosureConvoEvents}$conversationId/events'),
    );
    request.headers.addAll({
      ...await _headers(),
      'Accept': 'text/event-stream',
    });
    return client.send(request);
  }

  /// Persistent, always-open per-conversation event stream — separate from
  /// [streamChat] (the per-turn generation stream that closes once a reply
  /// finishes). Powers live human handoff: `message.created` events for
  /// messages sent by a business team member, and `agent-mode.changed`
  /// events when a team member silences/resumes the AI. Stays connected
  /// for the lifetime of the subscription; the server sends a `: heartbeat`
  /// comment line every 30s to keep it alive, which — like any line that
  /// isn't an SSE `data:` field — is ignored below.
  static Stream<Map<String, dynamic>> streamConversationEvents(
      String conversationId) {
    return _openEventStream(
      'streamConversationEvents($conversationId)',
      (client) => _openEventsStream(client, conversationId),
    );
  }
}
