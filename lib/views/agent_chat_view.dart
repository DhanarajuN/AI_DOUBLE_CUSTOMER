import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../routes/app_routes.dart';
import '../services/librechat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/message_bubble.dart';

/// One entry from an agent's `conversation_starters` (e.g.
/// `"pi-plus::Make a Claim"`) — icon key plus display label.
class _Starter {
  final String iconKey;
  final String label;
  const _Starter(this.iconKey, this.label);
}

/// One message in the live thread with this agent. Mutable so a streaming
/// assistant reply can grow `text` in place as deltas arrive.
class _Msg {
  final bool isMe;
  String text;
  final String time;
  bool isStreaming;
  _Msg({required this.isMe, required this.text, required this.time, this.isStreaming = false});
}

/// Route arguments for [AppRoutes.agentThread] — bundles the agent detail
/// with, optionally, an existing conversation to resume (its id and full
/// message history from LibreChatService.fetchMessages).
class AgentThreadArgs {
  final Map<String, dynamic> agent;
  final String? conversationId;
  final List<Map<String, dynamic>>? initialMessages;
  const AgentThreadArgs({required this.agent, this.conversationId, this.initialMessages});
}

/// Chat page for a single LibreChat agent. Either a fresh conversation
/// (opened after picking one from showNewRequestSheet(), see [open]) or an
/// existing one resumed from the chat list with its full history (see
/// [openExisting]). The app bar (name/avatar) and starter chips come from
/// the real agent response, and messages are sent/streamed via
/// LibreChatService.sendChatMessage/streamChat.
class AgentChatView extends StatefulWidget {
  final Map<String, dynamic> agent;
  final String? initialConversationId;
  final List<Map<String, dynamic>>? initialMessages;
  const AgentChatView({super.key, required this.agent, this.initialConversationId, this.initialMessages});

  /// Takes the agent summary from showNewRequestSheet() (which only has
  /// `id`/`name`/`description`/`avatar`), fetches the full detail by id —
  /// needed for `conversation_starters` — and pushes the chat page. Shows a
  /// loading dialog while fetching and a SnackBar if it fails.
  static Future<void> open(BuildContext context, Map<String, dynamic> agentSummary) async {
    final id = agentSummary['id'] as String?;
    if (id == null) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.appPrimaryColor),
        ),
      ),
    );

    try {
      final detail = await LibreChatService.fetchAgentById(id);
      if (!context.mounted) return;
      Navigator.of(context).pop(); // close loading dialog
      Navigator.of(context).pushNamed(AppRoutes.agentThread, arguments: AgentThreadArgs(agent: detail));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open agent: $e')),
      );
    }
  }

  /// Reopens a past conversation from the chat list — fetches the agent
  /// detail (by `agentId`) and the full message history (by
  /// `conversationId`) in parallel, then pushes the chat page pre-loaded
  /// with both, so sending a message continues that same conversation.
  static Future<void> openExisting(
    BuildContext context, {
    required String conversationId,
    required String agentId,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.appPrimaryColor),
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
      Navigator.of(context).pop(); // close loading dialog
      Navigator.of(context).pushNamed(
        AppRoutes.agentThread,
        arguments: AgentThreadArgs(agent: agent, conversationId: conversationId, initialMessages: messages),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open chat: $e')),
      );
    }
  }

  @override
  State<AgentChatView> createState() => _AgentChatViewState();
}

class _AgentChatViewState extends State<AgentChatView> {
  static const _rootParentMessageId = '00000000-0000-0000-0000-000000000000';

  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <_Msg>[];

  String? _conversationId;
  String _parentMessageId = _rootParentMessageId;
  bool _sending = false;
  bool _hasHistory = false;

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
            ? content.whereType<Map>().where((c) => c['type'] == 'text').map((c) => c['text'] as String).join('\n\n')
            : (m['text'] as String? ?? '');
        final createdAt = DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now();
        _messages.add(_Msg(isMe: isMe, text: text, time: _formatTime(createdAt)));
      }
      _parentMessageId = raw.last['messageId'] as String? ?? _rootParentMessageId;
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<_Starter> get _starters {
    final raw = (widget.agent['conversation_starters'] as List?)?.cast<String>() ?? const [];
    return raw
        .map((entry) {
          final parts = entry.split('::');
          return _Starter(parts[0], parts.length > 1 ? parts[1] : '');
        })
        // "__agenticon__::..." is metadata about the agent's own avatar, not
        // a real starter to show as a chip.
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
      SnackBar(content: Text('$what — coming soon'), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _timeNow() => _formatTime(DateTime.now());

  String _uuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    String hex(int start, int end) => bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
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
    if (text.isEmpty || _sending) return;

    final agentId = widget.agent['id'] as String?;
    if (agentId == null) return;

    _inputCtrl.clear();
    setState(() {
      _sending = true;
      _messages.add(_Msg(isMe: true, text: text, time: _timeNow()));
    });
    _scrollToBottom();

    final assistantMsg = _Msg(isMe: false, text: '', time: _timeNow(), isStreaming: true);

    try {
      final ack = await LibreChatService.sendChatMessage(
        agentId: agentId,
        text: text,
        messageId: _uuidV4(),
        parentMessageId: _parentMessageId,
        conversationId: _conversationId,
      );
      final streamId = ack['streamId'] as String? ?? ack['conversationId'] as String?;
      if (streamId == null) throw Exception('No streamId in response');
      _conversationId = ack['conversationId'] as String? ?? streamId;

      if (!mounted) return;
      setState(() => _messages.add(assistantMsg));
      _scrollToBottom();

      await for (final event in LibreChatService.streamChat(streamId)) {
        if (!mounted) return;
        if (event['event'] == 'on_message_delta') {
          final content = event['data']?['delta']?['content'] as List?;
          final chunk = (content != null && content.isNotEmpty) ? content[0]['text'] as String? ?? '' : '';
          if (chunk.isNotEmpty) {
            setState(() => assistantMsg.text += chunk);
            _scrollToBottom();
          }
        } else if (event['final'] == true) {
          final responseMessage = event['responseMessage'] as Map<String, dynamic>?;
          final contentList = responseMessage?['content'] as List?;
          final fullText = contentList
                  ?.where((c) => c is Map && c['type'] == 'text')
                  .map((c) => c['text'] as String)
                  .join('\n\n') ??
              assistantMsg.text;
          setState(() {
            assistantMsg.text = fullText.isEmpty ? assistantMsg.text : fullText;
            assistantMsg.isStreaming = false;
          });
          _parentMessageId = responseMessage?['messageId'] as String? ?? _parentMessageId;
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        assistantMsg.isStreaming = false;
        if (assistantMsg.text.isEmpty) {
          assistantMsg.text = 'Something went wrong: $e';
        }
        if (!_messages.contains(assistantMsg)) _messages.add(assistantMsg);
      });
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  // Agent text sometimes comes back as plain text and sometimes as
  // markdown (headings, bold, lists, ...) — render through MarkdownBody
  // either way; it degrades to plain text when there's no markdown syntax.
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
          border: Border(left: BorderSide(color: AppColors.appSecondaryColor, width: 3)),
        ),
      ),
    );
  }

  Widget _messageBubble(_Msg m) {
    if (m.isStreaming && m.text.isEmpty) {
      return const TypingIndicator();
    }
    return Align(
      alignment: m.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(11, 8, 11, 6),
        decoration: BoxDecoration(
          color: m.isMe ? AppColors.appChatBubbleMineColor : AppColors.appChatBubbleOtherColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(11),
            topRight: const Radius.circular(11),
            bottomLeft: Radius.circular(m.isMe ? 11 : 3),
            bottomRight: Radius.circular(m.isMe ? 3 : 11),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The user's own messages are shown as-is, never
            // markdown-rendered; agent replies go through _markdownText.
            m.isMe ? Text(m.text, style: AppFonts.body(size: 14)) : _markdownText(m.text),
            const SizedBox(height: 2),
            Text(
              m.time,
              style: AppFonts.body(size: 9.5, color: m.isMe ? AppColors.appTextColor.withOpacity(0.55) : AppColors.appTextMutedColor),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.agent['name'] as String? ?? 'Assistant';
    final description = widget.agent['description'] as String?;
    final avatar = widget.agent['avatar'] as Map<String, dynamic>?;
    final avatarIcon = avatar?['filepath'] == 'pi-sparkles' ? Icons.auto_awesome : Icons.smart_toy_outlined;
    final starters = _starters;
    final greeting = (description != null && description.isNotEmpty)
        ? description
        : "Hi! I'm $name. How can I help you today?";

    return Scaffold(
      backgroundColor: AppColors.appChatBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ---- app bar: name + avatar from the agent response ----
            Container(
              padding: const EdgeInsets.fromLTRB(6, 14, 8, 12),
              decoration: BoxDecoration(
                color: AppColors.appSurfaceColor,
                border: Border(bottom: BorderSide(color: AppColors.appBorderColor)),
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
                    decoration: BoxDecoration(gradient: AppColors.appPrimaryGradient, shape: BoxShape.circle),
                    child: Stack(
                      children: [
                        Center(child: Icon(avatarIcon, color: Colors.white, size: 18)),
                        Positioned(
                          bottom: -1,
                          right: -1,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.appSecondaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.appSurfaceColor, width: 2),
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
                                style: AppFonts.body(size: 15.5, weight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text('✓', style: TextStyle(color: AppColors.appPrimaryColor, fontSize: 12)),
                          ],
                        ),
                        Text('assistant · online', style: AppFonts.mono(size: 10, color: AppColors.appSuccessColor)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: AppColors.appTextSecondaryColor),
                    onPressed: () => _notWiredYet('Chat options'),
                  ),
                ],
              ),
            ),

            // ---- thread: TODAY mark + greeting bubble, then the live
            // message history sent/streamed via LibreChatService ----
            Expanded(
              child: Container(
                color: AppColors.appChatBackgroundColor,
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                  // Resumed conversations already have their own real
                  // greeting exchange in history — only synthesize a
                  // TODAY mark + greeting bubble for a brand-new chat.
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
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
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
                                Text(_timeNow(), style: AppFonts.body(size: 9.5, color: AppColors.appTextMutedColor)),
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

            // ---- conversation starters (bottom blocks) — hidden once the
            // user has sent a first message ----
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
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.appPrimaryColor.withOpacity(0.08),
                          border: Border.all(color: AppColors.appPrimaryColor),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_iconFor(s.iconKey), size: 14, color: AppColors.appPrimaryColor),
                            const SizedBox(width: 6),
                            Text(
                              s.label,
                              style: AppFonts.body(size: 12.5, weight: FontWeight.w500, color: AppColors.appPrimaryColor),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // ---- composer ----
            Container(
              padding: const EdgeInsets.all(8),
              color: AppColors.appSurfaceColor,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.add, color: AppColors.appTextSecondaryColor),
                    onPressed: () => _notWiredYet('Attach'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      style: AppFonts.body(size: 14),
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sending ? null : _send,
                      decoration: InputDecoration(
                        hintText: 'Message',
                        hintStyle: AppFonts.body(size: 14, color: AppColors.appTextMutedColor),
                        filled: true,
                        fillColor: AppColors.appSurfaceVariantColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(100),
                          borderSide: BorderSide(color: AppColors.appBorderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(100),
                          borderSide: BorderSide(color: AppColors.appBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(100),
                          borderSide: BorderSide(color: AppColors.appBorderColorStrong),
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
                        color: _sending ? AppColors.appPrimaryColor.withOpacity(0.35) : AppColors.appPrimaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(11),
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.appOnPrimaryColor),
                            )
                          : const Icon(Icons.arrow_upward, color: AppColors.appOnPrimaryColor, size: 19),
                    ),
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
