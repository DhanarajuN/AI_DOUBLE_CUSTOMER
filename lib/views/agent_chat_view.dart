import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import '../repositories/auth_repository.dart';
import '../routes/app_routes.dart';
import '../services/app_logger.dart';
import '../services/friendly_error.dart';
import '../services/librechat_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/business_picker_sheet.dart';
import '../widgets/message_bubble.dart';

class _Starter {
  final String iconKey;
  final String label;
  const _Starter(this.iconKey, this.label);
}

class _Msg {
  final bool isMe;
  String text;
  final String time;
  bool isStreaming;
  bool isError;
  // Server-assigned id — set on user messages up front (we generate it
  // before the request) and on assistant/business messages once known, so
  // events coming in over streamConversationEvents can be deduped against
  // whatever's already rendered here.
  String? messageId;
  // True for messages sent by a business team member during live handoff
  // (sender == 'Business' on the conversation-events stream) — rendered in
  // a visually distinct bubble from both the customer's own and the AI's.
  bool isBusiness;
  // The actual business's name (resolved server-side, see
  // Gosure/businessLookup.js), shown instead of a generic "Team member"
  // label when available.
  String? senderName;
  final List<_PendingAttachment> attachments;
  _Msg({
    required this.isMe,
    required this.text,
    required this.time,
    this.isStreaming = false,
    this.isError = false,
    this.messageId,
    this.isBusiness = false,
    this.senderName,
    this.attachments = const [],
  });
}

class _PendingAttachment {
  final String filename;
  final Uint8List bytes;
  final bool isImage;
  final int? width;
  final int? height;
  const _PendingAttachment({
    required this.filename,
    required this.bytes,
    required this.isImage,
    this.width,
    this.height,
  });
}

class AgentThreadArgs {
  final Map<String, dynamic> agent;
  final String? conversationId;
  final List<Map<String, dynamic>>? initialMessages;
  final String? businessId;
  const AgentThreadArgs(
      {required this.agent,
      this.conversationId,
      this.initialMessages,
      this.businessId});
}

class AgentChatView extends StatefulWidget {
  final Map<String, dynamic> agent;
  final String? initialConversationId;
  final List<Map<String, dynamic>>? initialMessages;
  final String? businessId;
  const AgentChatView(
      {super.key,
      required this.agent,
      this.initialConversationId,
      this.initialMessages,
      this.businessId});

  static Future<void> open(
      BuildContext context, Map<String, dynamic> agentSummary) async {
    final id = agentSummary['id'] as String?;
    if (id == null) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2.4, color: AppColors.appPrimaryColor),
        ),
      ),
    );

    Map<String, dynamic> detail;
    try {
      detail = await LibreChatService.fetchAgentById(id);
    } catch (e, st) {
      AppLogger.e('AgentChatView', 'open($id) failed', e, st);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open this agent. ${friendlyError(e)}')),
      );
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).pop();
    // Popping the loading dialog and immediately showing another overlay in
    // the same synchronous continuation races Flutter's own element-tree
    // teardown for the popped route — intermittently throws "_elements.contains
    // (element) is not true" once the new overlay tries to insert before the
    // pop has fully settled. Yielding a frame first (a Flutter-recommended,
    // low-risk fix for this exact class of Navigator race) is enough.
    await Future<void>.delayed(Duration.zero);
    if (!context.mounted) return;

    // Business-picker step: tag the conversation-to-be with which specific
    // business, within this agent's category, the customer is talking to —
    // the server needs this to support live human handoff later. The
    // agent's name doubles as its category (see new_request_sheet.dart).
    final category =
        (detail['name'] as String?) ?? (agentSummary['name'] as String?);
    String? businessId;
    if (category != null && category.isNotEmpty) {
      final picked = await showBusinessPickerSheet(context, category: category);
      if (picked == null) return; // sheet dismissed — treat as cancelling
      businessId = picked['id'] as String?;
    }

    if (!context.mounted) return;
    Navigator.of(context).pushNamed(AppRoutes.agentThread,
        arguments: AgentThreadArgs(agent: detail, businessId: businessId));
  }

  static Future<void> openExisting(
    BuildContext context, {
    required String conversationId,
    required String agentId,
    String? businessId,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2.4, color: AppColors.appPrimaryColor),
        ),
      ),
    );

    try {
      final results = await Future.wait([
        LibreChatService.fetchAgentById(agentId),
        LibreChatService.fetchMessages(conversationId),
      ]);
      final agent = results[0] as Map<String, dynamic>;
      final messages = results[1] as List<Map<String, dynamic>>;
      if (!context.mounted) return;
      Navigator.of(context).pop();
      // Same Navigator race as AgentChatView.open above — let the pop settle
      // before pushing the next route.
      await Future<void>.delayed(Duration.zero);
      if (!context.mounted) return;
      Navigator.of(context).pushNamed(
        AppRoutes.agentThread,
        arguments: AgentThreadArgs(
            agent: agent,
            conversationId: conversationId,
            initialMessages: messages,
            businessId: businessId),
      );
    } catch (e, st) {
      AppLogger.e(
          'AgentChatView', 'openExisting($conversationId) failed', e, st);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open this chat. ${friendlyError(e)}')),
      );
    }
  }

  @override
  State<AgentChatView> createState() => _AgentChatViewState();
}

class _AgentChatViewState extends State<AgentChatView> {
  static const _rootParentMessageId = '00000000-0000-0000-0000-000000000000';
  static const _maxAttachments = 5;
  static const _maxTotalAttachmentBytes = 20 * 1024 * 1024;
  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};

  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <_Msg>[];

  String? _conversationId;
  String _parentMessageId = _rootParentMessageId;
  bool _sending = false;
  bool _hasHistory = false;
  final _pendingAttachments = <_PendingAttachment>[];
  bool _pickingAttachments = false;
  List<String> _suggestedReplies = [];

  // Persistent conversation-events subscription (live handoff) — separate
  // from the per-turn stream opened inside _send(). Null until a real
  // conversationId exists (a brand-new conversation only gets one once the
  // first message is acked).
  StreamSubscription<Map<String, dynamic>>? _eventsSub;
  Timer? _eventsReconnectTimer;
  bool _teamMemberActive = false;

  @override
  void initState() {
    super.initState();
    final raw = widget.initialMessages;
    if (raw != null && raw.isNotEmpty) {
      _hasHistory = true;
      _conversationId = widget.initialConversationId;
      for (final m in raw) {
        final isMe = m['isCreatedByUser'] == true;
        final content = m['content'] as List?;
        final text = (content != null && content.isNotEmpty)
            ? content
                .whereType<Map>()
                .where((c) => c['type'] == 'text')
                .map((c) => c['text'] as String)
                .join('\n\n')
            : (m['text'] as String? ?? '');
        final createdAt = DateTime.tryParse(m['createdAt'] as String? ?? '') ??
            DateTime.now();
        _messages.add(_Msg(
          isMe: isMe,
          text: text,
          time: _formatTime(createdAt),
          messageId: m['messageId'] as String?,
          isBusiness: m['sender'] == 'Business',
          senderName: m['senderName'] as String?,
        ));
      }
      _parentMessageId =
          raw.last['messageId'] as String? ?? _rootParentMessageId;
      _hydrateHistoryAttachments(raw);
    }
    if (_conversationId != null) {
      _subscribeToEvents(_conversationId!);
      // Opening this screen with the full history already loaded is exactly what "seen"
      // means — mirrors AI_DOUBLE_BUSINESS's _markSeen. The chat list re-reads this the
      // next time it loads (didPopNext already reloads it on every return here).
      unawaited(SessionStorage()
          .saveLastSeenCount(_conversationId!, _messages.length));
    }
  }

  Future<void> _hydrateHistoryAttachments(
      List<Map<String, dynamic>> raw) async {
    for (var i = 0; i < raw.length; i++) {
      final files = raw[i]['files'] as List?;
      if (files == null || files.isEmpty) continue;

      final attachments = <_PendingAttachment>[];
      for (final f in files.cast<Map<String, dynamic>>()) {
        final metadata = f['metadata'] as Map<String, dynamic>?;
        final gosureAttachmentId = metadata?['gosureAttachmentId'] as String?;
        if (gosureAttachmentId == null) continue;
        try {
          final bytes =
              await LibreChatService.downloadAttachment(gosureAttachmentId);
          final isImage = (f['type'] as String? ?? '').startsWith('image/');
          int? width;
          int? height;
          if (isImage) {
            final decoded = await _decodeImage(bytes);
            width = decoded.width;
            height = decoded.height;
          }
          attachments.add(_PendingAttachment(
            filename: f['filename'] as String? ?? 'attachment',
            bytes: bytes,
            isImage: isImage,
            width: width,
            height: height,
          ));
        } catch (e, st) {
          AppLogger.e('AgentChatView',
              'downloadAttachment($gosureAttachmentId) failed', e, st);
        }
      }

      if (attachments.isEmpty || !mounted) continue;
      setState(() {
        final old = _messages[i];
        _messages[i] = _Msg(
          isMe: old.isMe,
          text: old.text,
          time: old.time,
          messageId: old.messageId,
          isBusiness: old.isBusiness,
          senderName: old.senderName,
          attachments: attachments,
        );
      });
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _eventsSub?.cancel();
    _eventsReconnectTimer?.cancel();
    super.dispose();
  }

  void _subscribeToEvents(String conversationId) {
    if (_eventsSub != null) return;
    AppLogger.i('AgentChatView',
        'subscribing to conversation events for $conversationId');
    // This stream is how a business's live human-handoff messages arrive —
    // it previously had no reconnect handling at all, so any drop (network
    // blip, backend redeploy) silently and permanently stopped live messages
    // from reaching this screen, with no error shown and nothing to prompt a
    // retry. Mirrors AI_DOUBLE_BUSINESS's own conversation-events reconnect.
    _eventsSub =
        LibreChatService.streamConversationEvents(conversationId).listen(
      _handleConvoEvent,
      onError: (e, st) {
        AppLogger.e(
            'AgentChatView', 'streamConversationEvents failed, will retry', e, st);
        _reconnectEventsSoon(conversationId);
      },
      onDone: () {
        AppLogger.w('AgentChatView',
            'streamConversationEvents closed, will retry');
        _reconnectEventsSoon(conversationId);
      },
      cancelOnError: true,
    );
  }

  void _reconnectEventsSoon(String conversationId) {
    _eventsSub = null;
    _eventsReconnectTimer?.cancel();
    _eventsReconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || conversationId != _conversationId) return;
      _subscribeToEvents(conversationId);
    });
  }

  void _handleConvoEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    if (type == 'message.created') {
      final message = event['message'] as Map<String, dynamic>?;
      if (message == null) return;
      final id = message['messageId'] as String?;
      final isBusiness = message['sender'] == 'Business';
      final isCreatedByUser = message['isCreatedByUser'] == true;
      // Dedupe against anything this screen already rendered — our own
      // sent messages and the AI's streamed reply both echo back here.
      if (id != null && _messages.any((m) => m.messageId == id)) return;
      // The AI's own reply to a message this screen is actively streaming
      // arrives here too, and server-side persistence (which triggers this
      // event) can race ahead of the per-turn stream finishing client-side —
      // the streaming bubble's messageId isn't assigned until its own
      // stream's `final` event (see _send below), so the id check above can
      // miss it and this would otherwise render as a second copy of the same
      // reply. Skip it here; the streaming bubble already shows it and will
      // carry the same id once its own stream completes.
      if (!isCreatedByUser &&
          !isBusiness &&
          _messages.any((m) => !m.isMe && !m.isBusiness && m.isStreaming)) {
        return;
      }
      // Agent replies are stored with `text` as an empty string (not null) and their
      // real body nested under `content` instead — fall back to that before giving up.
      final rawText = message['text'] as String?;
      final content = message['content'] as List?;
      final extractedText = (content != null && content.isNotEmpty)
          ? content
              .whereType<Map>()
              .where((c) => c['type'] == 'text')
              .map((c) => c['text']?.toString() ?? '')
              .join('\n\n')
          : null;
      final text = (rawText != null && rawText.isNotEmpty)
          ? rawText
          : (extractedText ?? '');
      if (text.isEmpty) return;
      final createdAt =
          DateTime.tryParse(message['createdAt'] as String? ?? '') ??
              DateTime.now();
      if (!mounted) return;
      setState(() {
        _messages.add(_Msg(
          isMe: message['isCreatedByUser'] == true,
          text: text,
          time: _formatTime(createdAt),
          messageId: id,
          isBusiness: isBusiness,
          senderName: message['senderName'] as String?,
        ));
      });
      _parentMessageId = id ?? _parentMessageId;
      _scrollToBottom();
      // Screen is open right now, so a message arriving live counts as seen immediately.
      if (_conversationId != null) {
        unawaited(SessionStorage()
            .saveLastSeenCount(_conversationId!, _messages.length));
      }
    } else if (type == 'agent-mode.changed') {
      if (!mounted) return;
      setState(() => _teamMemberActive = event['agentChatMode'] == false);
    }
  }

  List<_Starter> get _starters {
    final raw =
        (widget.agent['conversation_starters'] as List?)?.cast<String>() ??
            const [];
    return raw
        .map((entry) {
          final parts = entry.split('::');
          return _Starter(parts[0], parts.length > 1 ? parts[1] : '');
        })
        .where((s) => !s.iconKey.startsWith('__') && s.label.isNotEmpty)
        .toList();
  }

  IconData _iconFor(String key) {
    switch (key.replaceFirst('pi-', '')) {
      case 'plus':
        return Icons.add;
      case 'eye':
        return Icons.visibility_outlined;
      case 'pencil':
        return Icons.edit_outlined;
      case 'sparkles':
        return Icons.auto_awesome;
      case 'trash':
        return Icons.delete_outline;
      case 'check':
        return Icons.check_circle_outline;
      case 'chat':
        return Icons.chat_bubble_outline;
      case 'file':
        return Icons.description_outlined;
      case 'calendar':
        return Icons.calendar_today_outlined;
      case 'clock':
        return Icons.access_time;
      case 'search':
        return Icons.search;
      case 'user':
        return Icons.person_outline;
      case 'gear':
      case 'settings':
        return Icons.settings_outlined;
      case 'question':
        return Icons.help_outline;
      case 'list':
        return Icons.list_alt_outlined;
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'info':
        return Icons.info_outline;
      default:
        return Icons.bolt_outlined;
    }
  }

  void _notWiredYet(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('$what — coming soon'),
          behavior: SnackBarBehavior.floating),
    );
  }

  int get _pendingAttachmentBytes =>
      _pendingAttachments.fold(0, (sum, a) => sum + a.bytes.length);

  void _warn(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pickAttachments() async {
    if (_pickingAttachments) return;
    setState(() => _pickingAttachments = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: [..._imageExtensions, 'pdf'],
      );
      if (result == null) return;

      var skippedForCount = false;
      var skippedForSize = false;
      var totalBytes = _pendingAttachmentBytes;

      for (final file in result.files) {
        if (file.bytes == null) continue;
        if (_pendingAttachments.length >= _maxAttachments) {
          skippedForCount = true;
          break;
        }
        if (totalBytes + file.bytes!.length > _maxTotalAttachmentBytes) {
          skippedForSize = true;
          continue;
        }

        final extension = (file.extension ?? '').toLowerCase();
        final isImage = _imageExtensions.contains(extension);
        int? width;
        int? height;
        if (isImage) {
          final decoded = await _decodeImage(file.bytes!);
          width = decoded.width;
          height = decoded.height;
        }

        _pendingAttachments.add(_PendingAttachment(
          filename: file.name,
          bytes: file.bytes!,
          isImage: isImage,
          width: width,
          height: height,
        ));
        totalBytes += file.bytes!.length;
      }

      AppLogger.i('AgentChatView',
          'pickAttachments picked=${result.files.length} accepted=${_pendingAttachments.length} skippedForCount=$skippedForCount skippedForSize=$skippedForSize');
      if (skippedForCount) {
        _warn('Only up to $_maxAttachments attachments allowed');
      }
      if (skippedForSize) _warn('Attachments can\'t total more than 20MB');
      setState(() {});
    } catch (e, st) {
      AppLogger.e('AgentChatView', 'pickAttachments failed', e, st);
      _warn('Could not attach files');
    } finally {
      if (mounted) setState(() => _pickingAttachments = false);
    }
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _timeNow() => _formatTime(DateTime.now());

  String _uuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String rawText) async {
    final text = rawText.trim();
    final attachments = List<_PendingAttachment>.of(_pendingAttachments);
    if ((text.isEmpty && attachments.isEmpty) || _sending) return;

    final agentId = widget.agent['id'] as String?;
    if (agentId == null) return;

    final userMessageId = _uuidV4();
    _inputCtrl.clear();
    setState(() {
      _sending = true;
      _pendingAttachments.clear();
      _suggestedReplies = [];
      _messages.add(_Msg(
        isMe: true,
        text: text,
        time: _timeNow(),
        messageId: userMessageId,
        attachments: attachments,
      ));
    });
    _scrollToBottom();

    final assistantMsg =
        _Msg(isMe: false, text: '', time: _timeNow(), isStreaming: true);

    AppLogger.i('AgentChatView',
        'send agentId=$agentId conversationId=$_conversationId businessId=${widget.businessId} textLen=${text.length} attachments=${attachments.length}');

    try {
      final uploadedFiles = <Map<String, dynamic>>[];
      for (final attachment in attachments) {
        AppLogger.i('AgentChatView',
            'uploading attachment ${attachment.filename} (${attachment.bytes.length} bytes)');
        final gosureFile = await LibreChatService.uploadToGosureAttachments(
          bytes: attachment.bytes,
          filename: attachment.filename,
        );
        final file = await LibreChatService.uploadAttachment(
          agentId: agentId,
          bytes: attachment.bytes,
          filename: attachment.filename,
          fileId: _uuidV4(),
          width: attachment.isImage ? attachment.width : null,
          height: attachment.isImage ? attachment.height : null,
        );
        AppLogger.i('AgentChatView',
            'uploaded ${attachment.filename} -> gosureAttachmentId=${gosureFile['id']} librechatFileId=${file['file_id']}');
        uploadedFiles.add({
          ...file,
          'metadata': {
            ...(file['metadata'] as Map? ?? {}),
            'gosureAttachmentId': gosureFile['id'],
            'gosureDownloadKey': gosureFile['downloadKey'],
          },
        });
      }

      final ack = await LibreChatService.sendChatMessage(
        agentId: agentId,
        text: text,
        messageId: userMessageId,
        parentMessageId: _parentMessageId,
        conversationId: _conversationId,
        businessId: widget.businessId,
        senderName: context.read<AuthRepository>().currentUser?.name,
        files: uploadedFiles,
      );
      final streamId =
          ack['streamId'] as String? ?? ack['conversationId'] as String?;
      if (streamId == null) throw Exception('No streamId in response');
      _conversationId = ack['conversationId'] as String? ?? streamId;
      AppLogger.i('AgentChatView',
          'sendChatMessage ack streamId=$streamId conversationId=$_conversationId');
      _subscribeToEvents(_conversationId!);

      if (!mounted) return;
      setState(() => _messages.add(assistantMsg));
      _scrollToBottom();

      var deltaCount = 0;
      await for (final event in LibreChatService.streamChat(streamId)) {
        if (!mounted) return;
        if (event['event'] == 'on_message_delta') {
          final content = event['data']?['delta']?['content'] as List?;
          final chunk = (content != null && content.isNotEmpty)
              ? content[0]['text'] as String? ?? ''
              : '';
          if (chunk.isNotEmpty) {
            deltaCount++;
            setState(() => assistantMsg.text += chunk);
            _scrollToBottom();
          }
        } else if (event['final'] == true) {
          final responseMessage =
              event['responseMessage'] as Map<String, dynamic>?;
          final contentList = responseMessage?['content'] as List?;
          final errorEntry = contentList?.firstWhere(
            (c) => c is Map && c['type'] == 'error',
            orElse: () => null,
          );
          final fullText = contentList
                  ?.where((c) => c is Map && c['type'] == 'text')
                  .map((c) => c['text'] as String)
                  .join('\n\n') ??
              assistantMsg.text;
          AppLogger.i('AgentChatView',
              'stream final: deltas=$deltaCount hasError=${errorEntry != null} textLen=${fullText.length} messageId=${responseMessage?['messageId']}');
          setState(() {
            if (errorEntry != null) {
              assistantMsg.text = errorEntry['error'] as String? ??
                  'The agent returned an error.';
              assistantMsg.isError = true;
            } else {
              assistantMsg.text =
                  fullText.isEmpty ? assistantMsg.text : fullText;
            }
            assistantMsg.isStreaming = false;
          });
          assistantMsg.messageId = responseMessage?['messageId'] as String?;
          _parentMessageId =
              responseMessage?['messageId'] as String? ?? _parentMessageId;
        }
      }

      try {
        final suggestions = await LibreChatService.suggestReplies(
          conversationId: _conversationId!,
          lastUserMessage: text,
          agentDescription: widget.agent['description'] as String?,
        );
        AppLogger.i('AgentChatView',
            'suggestReplies -> ${suggestions.length} suggestions');
        if (mounted) setState(() => _suggestedReplies = suggestions);
      } catch (e, st) {
        AppLogger.e('AgentChatView', 'suggestReplies failed', e, st);
      }
    } catch (e, st) {
      AppLogger.e('AgentChatView', 'streamChat failed', e, st);
      if (!mounted) return;
      setState(() {
        assistantMsg.isStreaming = false;
        if (assistantMsg.text.isEmpty) {
          assistantMsg.text = friendlyError(e);
          assistantMsg.isError = true;
        }
        if (!_messages.contains(assistantMsg)) _messages.add(assistantMsg);
      });
    } finally {
      AppLogger.i(
          'AgentChatView', 'send complete conversationId=$_conversationId');
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  Widget _markdownText(String text) {
    return MarkdownBody(
      data: text,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet(
        p: AppFonts.body(size: 14),
        strong: AppFonts.body(size: 14, weight: FontWeight.w700),
        em: AppFonts.body(size: 14).copyWith(fontStyle: FontStyle.italic),
        listBullet: AppFonts.body(size: 14),
        code: AppFonts.mono(size: 12.5, color: AppColors.appTextColor),
        codeblockDecoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(6),
        ),
        h1: AppFonts.body(size: 18, weight: FontWeight.w700),
        h2: AppFonts.body(size: 16.5, weight: FontWeight.w700),
        h3: AppFonts.body(size: 15, weight: FontWeight.w700),
        blockquoteDecoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          border: Border(
              left: BorderSide(color: AppColors.appSecondaryColor, width: 3)),
        ),
      ),
    );
  }

  Widget _avatarFor(_Msg m) {
    if (m.isMe) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
            color: AppColors.appPrimaryColor.withOpacity(0.15),
            shape: BoxShape.circle),
        alignment: Alignment.center,
        child: const Icon(Icons.person, size: 14, color: AppColors.appPrimaryColor),
      );
    }
    if (m.isBusiness) {
      final name = m.senderName?.trim() ?? '';
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
            color: AppColors.appSecondaryColor, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'B',
            style: AppFonts.body(
                size: 11.5, weight: FontWeight.w700, color: Colors.white)),
      );
    }
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
          gradient: AppColors.appPrimaryGradient, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: const Icon(Icons.smart_toy_outlined, size: 13, color: Colors.white),
    );
  }

  Widget _messageBubble(_Msg m) {
    if (m.isStreaming && m.text.isEmpty) {
      return const TypingIndicator();
    }
    final avatar = _avatarFor(m);
    final bubble = Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(11, 8, 11, 6),
        decoration: BoxDecoration(
          color: m.isError
              ? const Color(0xFFD64545).withOpacity(0.12)
              : m.isBusiness
                  ? AppColors.appSecondaryColorDim
                  : m.isMe
                      ? AppColors.appChatBubbleMineColor
                      : AppColors.appChatBubbleOtherColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(11),
            topRight: const Radius.circular(11),
            bottomLeft: Radius.circular(m.isMe ? 11 : 3),
            bottomRight: Radius.circular(m.isMe ? 3 : 11),
          ),
          border: m.isError
              ? Border.all(color: const Color(0xFFD64545).withOpacity(0.4))
              : m.isBusiness
                  ? Border.all(
                      color: AppColors.appSecondaryColor.withOpacity(0.4))
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                m.isMe
                    ? 'YOU'
                    : m.isBusiness
                        ? (m.senderName ?? 'Team member').toUpperCase()
                        : 'AI AGENT',
                style: AppFonts.mono(
                    size: 9,
                    color: m.isMe
                        ? AppColors.appPrimaryColor
                        : m.isBusiness
                            ? AppColors.appSecondaryColor
                            : AppColors.appTextMutedColor,
                    letterSpacing: 0.8)),
            const SizedBox(height: 3),
            if (m.attachments.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: m.attachments.map((a) {
                  if (a.isImage) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(a.bytes,
                          width: 92, height: 92, fit: BoxFit.cover),
                    );
                  }
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf_outlined, size: 16),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            a.filename,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.body(size: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
            ],
            if (m.text.isNotEmpty)
              m.isError
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 16, color: Color(0xFFD64545)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            m.text,
                            style: AppFonts.body(size: 14)
                                .copyWith(color: const Color(0xFFD64545)),
                          ),
                        ),
                      ],
                    )
                  : m.isMe
                      ? Text(m.text, style: AppFonts.body(size: 14))
                      : _markdownText(m.text),
            const SizedBox(height: 2),
            Text(
              m.time,
              style: AppFonts.body(
                  size: 9.5,
                  color: m.isMe
                      ? AppColors.appTextColor.withOpacity(0.55)
                      : AppColors.appTextMutedColor),
            ),
          ],
        ),
      );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment:
            m.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: m.isMe
            ? [Flexible(child: bubble), const SizedBox(width: 6), avatar]
            : [avatar, const SizedBox(width: 6), Flexible(child: bubble)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.agent['name'] as String? ?? 'Assistant';
    final description = widget.agent['description'] as String?;
    final avatar = widget.agent['avatar'] as Map<String, dynamic>?;
    final avatarIcon = avatar?['filepath'] == 'pi-sparkles'
        ? Icons.auto_awesome
        : Icons.smart_toy_outlined;
    final starters = _starters;
    final greeting = (description != null && description.isNotEmpty)
        ? description
        : "Hi! I'm $name. How can I help you today?";

    return Scaffold(
      backgroundColor: AppColors.appChatBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(6, 14, 8, 12),
              decoration: BoxDecoration(
                color: AppColors.appSurfaceColor,
                border:
                    Border(bottom: BorderSide(color: AppColors.appBorderColor)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        gradient: AppColors.appPrimaryGradient,
                        shape: BoxShape.circle),
                    child: Stack(
                      children: [
                        Center(
                            child: Icon(avatarIcon,
                                color: Colors.white, size: 18)),
                        Positioned(
                          bottom: -1,
                          right: -1,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.appSecondaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.appSurfaceColor, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.body(
                                    size: 15.5, weight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text('✓',
                                style: TextStyle(
                                    color: AppColors.appPrimaryColor,
                                    fontSize: 12)),
                          ],
                        ),
                        Text('assistant · online',
                            style: AppFonts.mono(
                                size: 10, color: AppColors.appSuccessColor)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert,
                        color: AppColors.appTextSecondaryColor),
                    onPressed: () => _notWiredYet('Chat options'),
                  ),
                ],
              ),
            ),
            if (_teamMemberActive)
              Container(
                width: double.infinity,
                color: AppColors.appSecondaryColorDim,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.support_agent,
                        size: 15, color: AppColors.appSecondaryColor),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'A team member has joined this conversation',
                        style: AppFonts.body(
                            size: 12,
                            weight: FontWeight.w600,
                            color: AppColors.appSecondaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Container(
                color: AppColors.appChatBackgroundColor,
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                  itemCount: (_hasHistory ? 0 : 2) + _messages.length,
                  itemBuilder: (context, i) {
                    if (!_hasHistory) {
                      if (i == 0) {
                        return const DayMarkWidget(label: 'TODAY');
                      }
                      if (i == 1) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.82),
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.fromLTRB(11, 8, 11, 6),
                            decoration: BoxDecoration(
                              color: AppColors.appChatBubbleOtherColor,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(11),
                                topRight: Radius.circular(11),
                                bottomLeft: Radius.circular(3),
                                bottomRight: Radius.circular(11),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _markdownText(greeting),
                                const SizedBox(height: 2),
                                Text(_timeNow(),
                                    style: AppFonts.body(
                                        size: 9.5,
                                        color: AppColors.appTextMutedColor)),
                              ],
                            ),
                          ),
                        );
                      }
                      return _messageBubble(_messages[i - 2]);
                    }
                    return _messageBubble(_messages[i]);
                  },
                ),
              ),
            ),
            if (starters.isNotEmpty && _messages.isEmpty)
              Container(
                width: double.infinity,
                color: AppColors.appChatBackgroundColor,
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 3),
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: starters.map((s) {
                    return InkWell(
                      onTap: () => _send(s.label),
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.appPrimaryColor.withOpacity(0.08),
                          border: Border.all(color: AppColors.appPrimaryColor),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_iconFor(s.iconKey),
                                size: 14, color: AppColors.appPrimaryColor),
                            const SizedBox(width: 6),
                            Text(
                              s.label,
                              style: AppFonts.body(
                                  size: 12.5,
                                  weight: FontWeight.w500,
                                  color: AppColors.appPrimaryColor),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              )
            else if (_suggestedReplies.isNotEmpty && !_sending)
              Container(
                width: double.infinity,
                color: AppColors.appChatBackgroundColor,
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 3),
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: _suggestedReplies.map((reply) {
                    return InkWell(
                      onTap: () => _send(reply),
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.appPrimaryColor.withOpacity(0.08),
                          border: Border.all(color: AppColors.appPrimaryColor),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          reply,
                          style: AppFonts.body(
                              size: 12.5,
                              weight: FontWeight.w500,
                              color: AppColors.appPrimaryColor),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(8),
              color: AppColors.appSurfaceColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_pendingAttachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        height: 64,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _pendingAttachments.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final attachment = _pendingAttachments[i];
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                if (attachment.isImage)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(attachment.bytes,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover),
                                  )
                                else
                                  Container(
                                    width: 64,
                                    height: 64,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.appSurfaceVariantColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: AppColors.appBorderColor),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                            Icons.picture_as_pdf_outlined,
                                            size: 20),
                                        const SizedBox(height: 3),
                                        Text(
                                          attachment.filename,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppFonts.body(size: 9),
                                        ),
                                      ],
                                    ),
                                  ),
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: InkWell(
                                    onTap: () => setState(
                                        () => _pendingAttachments.removeAt(i)),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: const BoxDecoration(
                                          color: Colors.black87,
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.close,
                                          size: 13, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        icon: _pickingAttachments
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.appTextSecondaryColor),
                              )
                            : Icon(Icons.add,
                                color: AppColors.appTextSecondaryColor),
                        onPressed:
                            _pickingAttachments ? null : _pickAttachments,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _inputCtrl,
                          style: AppFonts.body(size: 14),
                          textInputAction: TextInputAction.send,
                          onSubmitted: _sending ? null : _send,
                          decoration: InputDecoration(
                            hintText: 'Message',
                            hintStyle: AppFonts.body(
                                size: 14, color: AppColors.appTextMutedColor),
                            filled: true,
                            fillColor: AppColors.appSurfaceVariantColor,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 11),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(100),
                              borderSide:
                                  BorderSide(color: AppColors.appBorderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(100),
                              borderSide:
                                  BorderSide(color: AppColors.appBorderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(100),
                              borderSide: BorderSide(
                                  color: AppColors.appBorderColorStrong),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _sending ? null : () => _send(_inputCtrl.text),
                        borderRadius: BorderRadius.circular(21),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _sending
                                ? AppColors.appPrimaryColor.withOpacity(0.35)
                                : AppColors.appPrimaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: _sending
                              ? const Padding(
                                  padding: EdgeInsets.all(11),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.appOnPrimaryColor),
                                )
                              : const Icon(Icons.arrow_upward,
                                  color: AppColors.appOnPrimaryColor, size: 19),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
