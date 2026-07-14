import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/auth_repository.dart';
import '../routes/app_routes.dart';
import '../services/librechat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/new_request_sheet.dart';
import 'agent_chat_view.dart';

/// Chat list — backed by real LibreChat conversations (LibreChatService.
/// fetchConversations) rather than the mock ConvoRepository. That API only
/// gives title/agent_id/updatedAt, so there's no unread badge, message
/// preview, or archive here (those had no dynamic backing data); tapping
/// a past conversation is a no-op for now until a message-history
/// endpoint is wired up — new chats still go through showNewRequestSheet.
class ChatListView extends StatefulWidget {
  const ChatListView({super.key});

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final convos = await LibreChatService.fetchConversations();
      if (!mounted) return;
      setState(() {
        _conversations = convos;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _conversations;
    return _conversations.where((c) => ((c['title'] as String?) ?? '').toLowerCase().contains(q)).toList();
  }

  String _relativeTime(String? iso) {
    final dt = iso == null ? null : DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.isNotEmpty;
    final results = _visible;

    return Scaffold(
      backgroundColor: AppColors.app,
      body: SafeArea(
        child: Column(
          children: [
            _buildBar(context),
            Expanded(
              child: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.teal,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 90),
                      children: [
                        _buildSearchBar(),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.teal),
                              ),
                            ),
                          )
                        else if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Center(
                              child: Text(
                                'Could not load chats. Pull to refresh.',
                                style: AppFonts.body(size: 13.5, color: AppColors.dim),
                              ),
                            ),
                          )
                        else ...[
                          for (final c in results) _conversationRow(c),
                          if (searching && results.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Center(
                                child: Text(
                                  'No chats matching "$_query"',
                                  style: AppFonts.body(size: 13.5, color: AppColors.dim),
                                ),
                              ),
                            ),
                          if (!searching && results.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Center(
                                child: Text(
                                  'No chats yet — tap + to start one.',
                                  style: AppFonts.body(size: 13.5, color: AppColors.dim),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    right: 20,
                    bottom: 24,
                    child: FloatingActionButton(
                      backgroundColor: AppColors.teal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      onPressed: () async {
                        final agent = await showNewRequestSheet(context);
                        if (agent != null && context.mounted) {
                          await AgentChatView.open(context, agent);
                        }
                      },
                      child: const Icon(Icons.add, color: Color(0xFF04120D), size: 26),
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

  Widget _conversationRow(Map<String, dynamic> convo) {
    final title = convo['title'] as String? ?? 'Untitled chat';
    final time = _relativeTime(convo['updatedAt'] as String?);
    final conversationId = convo['conversationId'] as String?;
    final agentId = convo['agent_id'] as String?;
    return InkWell(
      onTap: (conversationId == null || agentId == null)
          ? null
          : () => AgentChatView.openExisting(context, conversationId: conversationId, agentId: agentId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(gradient: AppColors.tealGradient, shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(bottom: 11),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.body(size: 15.5, weight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(time, style: AppFonts.body(size: 11, color: AppColors.faint)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppColors.tealGradient,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Stack(
              children: [
                const Center(child: Icon(Icons.forum_outlined, color: Colors.white, size: 18)),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 8,
                    height: 8,
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
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: AppFonts.display(size: 19),
                    children: [
                      const TextSpan(text: 'AI '),
                      TextSpan(text: 'Double', style: AppFonts.display(size: 19, weight: FontWeight.w400, color: AppColors.gold).copyWith(fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                Text('CHATS', style: AppFonts.mono(size: 10, letterSpacing: 1)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.dim),
            onPressed: () => _searchFocus.requestFocus(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.dim),
            color: AppColors.panel2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'logout') _confirmLogout(context);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'logout',
                child: Text('Log out', style: AppFonts.body(size: 13.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: AppColors.panel2,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 16, color: AppColors.faint),
            const SizedBox(width: 9),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                onChanged: (v) => setState(() => _query = v),
                style: AppFonts.body(size: 13.5),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search chats…',
                  hintStyle: AppFonts.body(size: 13.5, color: AppColors.faint),
                ),
              ),
            ),
            if (_query.isNotEmpty)
              InkWell(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 9),
                  child: Icon(Icons.close, size: 16, color: AppColors.faint),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log out?', style: AppFonts.display(size: 17)),
        content: Text(
          "You'll need to sign in again to access your chats.",
          style: AppFonts.body(size: 13.5, color: AppColors.dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppFonts.body(size: 14, color: AppColors.dim)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Log out', style: AppFonts.body(size: 14, weight: FontWeight.w600, color: AppColors.teal)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthRepository>().logout();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      }
    }
  }
}
