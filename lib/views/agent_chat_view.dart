import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../services/librechat_service.dart';
import '../theme/app_theme.dart';

/// One entry from an agent's `conversation_starters` (e.g.
/// `"pi-plus::Make a Claim"`) — icon key plus display label.
class _Starter {
  final String iconKey;
  final String label;
  const _Starter(this.iconKey, this.label);
}

/// Chat page for a single LibreChat agent, opened after picking one from
/// showNewRequestSheet() and fetching its full detail via
/// LibreChatService.fetchAgentById(). Mirrors ChatThreadView's static
/// layout, but the app bar (name/avatar) and starter chips are populated
/// from the real agent response instead of the mock script data.
class AgentChatView extends StatefulWidget {
  final Map<String, dynamic> agent;
  const AgentChatView({super.key, required this.agent});

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
          child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.teal),
        ),
      ),
    );

    try {
      final detail = await LibreChatService.fetchAgentById(id);
      if (!context.mounted) return;
      Navigator.of(context).pop(); // close loading dialog
      Navigator.of(context).pushNamed(AppRoutes.agentThread, arguments: detail);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open agent: $e')),
      );
    }
  }

  @override
  State<AgentChatView> createState() => _AgentChatViewState();
}

class _AgentChatViewState extends State<AgentChatView> {
  final _inputCtrl = TextEditingController();

  @override
  void dispose() {
    _inputCtrl.dispose();
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

  String _timeNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
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
      backgroundColor: AppColors.chatBg,
      body: SafeArea(
        child: Column(
          children: [
            // ---- app bar: name + avatar from the agent response ----
            Container(
              padding: const EdgeInsets.fromLTRB(6, 14, 8, 12),
              decoration: const BoxDecoration(
                color: AppColors.panel,
                border: Border(bottom: BorderSide(color: AppColors.line)),
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
                    decoration: const BoxDecoration(gradient: AppColors.tealGradient, shape: BoxShape.circle),
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
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.panel, width: 2),
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
                            const Text('✓', style: TextStyle(color: AppColors.teal, fontSize: 12)),
                          ],
                        ),
                        Text('assistant · online', style: AppFonts.mono(size: 10, color: AppColors.green)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: AppColors.dim),
                    onPressed: () => _notWiredYet('Chat options'),
                  ),
                ],
              ),
            ),

            // ---- thread: a "TODAY" mark + the agent's greeting bubble
            // (from its `description`) — real message history isn't wired
            // up yet, this is just the opening state.
            Expanded(
              child: Container(
                color: AppColors.chatBg,
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.panel2,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text('TODAY', style: AppFonts.mono(size: 10.5, letterSpacing: 0.6)),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.fromLTRB(11, 8, 11, 6),
                        decoration: const BoxDecoration(
                          color: AppColors.other,
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
                            Text(greeting, style: AppFonts.body(size: 14)),
                            const SizedBox(height: 2),
                            Text(_timeNow(), style: AppFonts.body(size: 9.5, color: AppColors.faint)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ---- conversation starters (bottom blocks) ----
            if (starters.isNotEmpty)
              Container(
                width: double.infinity,
                color: AppColors.chatBg,
                padding: const EdgeInsets.fromLTRB(12, 7, 12, 3),
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: starters.map((s) {
                    return InkWell(
                      onTap: () => _notWiredYet('Sending "${s.label}"'),
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withOpacity(0.08),
                          border: Border.all(color: AppColors.teal),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_iconFor(s.iconKey), size: 14, color: AppColors.teal),
                            const SizedBox(width: 6),
                            Text(
                              s.label,
                              style: AppFonts.body(size: 12.5, weight: FontWeight.w500, color: AppColors.teal),
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
              color: AppColors.panel,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add, color: AppColors.dim),
                    onPressed: () => _notWiredYet('Attach'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      style: AppFonts.body(size: 14),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _notWiredYet('Sending messages'),
                      decoration: InputDecoration(
                        hintText: 'Message',
                        hintStyle: AppFonts.body(size: 14, color: AppColors.faint),
                        filled: true,
                        fillColor: AppColors.panel2,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(100),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(100),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(100),
                          borderSide: const BorderSide(color: AppColors.line2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _notWiredYet('Sending messages'),
                    borderRadius: BorderRadius.circular(21),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_upward, color: Color(0xFF04120D), size: 19),
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
