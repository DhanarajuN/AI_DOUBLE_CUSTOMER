import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/convo.dart';
import '../repositories/auth_repository.dart';
import '../repositories/convo_repository.dart';
import '../repositories/pro_repository.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../viewmodels/chat_list_view_model.dart';
import '../widgets/chat_row.dart';
import '../widgets/new_request_sheet.dart';

class ChatListView extends StatelessWidget {
  const ChatListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ChatListViewModel(
        ctx.read<ConvoRepository>(),
        ctx.read<ProRepository>(),
      ),
      child: const _ChatListBody(),
    );
  }
}

class _ChatListBody extends StatefulWidget {
  const _ChatListBody();

  @override
  State<_ChatListBody> createState() => _ChatListBodyState();
}

class _ChatListBodyState extends State<_ChatListBody> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ChatListViewModel>();
    final searching = vm.query.isNotEmpty;
    final results = vm.visibleConvos;

    return Scaffold(
      backgroundColor: AppColors.app,
      body: SafeArea(
        child: Column(
          children: [
            _buildBar(context),
            Expanded(
              child: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.only(bottom: 90),
                    children: [
                      _buildSearchBar(context, vm),
                      if (!searching) _buildArchiveStrip(context, vm),
                      for (final c in results)
                        ChatRow(
                          convo: c,
                          pro: vm.proFor(c),
                          onTap: () {
                            vm.openConvo(c.id);
                            Navigator.of(context).pushNamed(AppRoutes.chatThread, arguments: c.id);
                          },
                          onLongPress: () => _confirmArchive(context, vm, c),
                        ),
                      if (searching && results.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              'No chats matching "${vm.query}"',
                              style: AppFonts.body(size: 13.5, color: AppColors.dim),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Positioned(
                    right: 20,
                    bottom: 24,
                    child: FloatingActionButton(
                      backgroundColor: AppColors.teal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      onPressed: () async {
                        final category = await showNewRequestSheet(context);
                        if (category != null && context.mounted) {
                          final convoId = vm.startIntake(category);
                          Navigator.of(context).pushNamed(AppRoutes.chatThread, arguments: convoId);
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

  Widget _buildSearchBar(BuildContext context, ChatListViewModel vm) {
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
                onChanged: vm.setQuery,
                style: AppFonts.body(size: 13.5),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search chats…',
                  hintStyle: AppFonts.body(size: 13.5, color: AppColors.faint),
                ),
              ),
            ),
            if (vm.query.isNotEmpty)
              InkWell(
                onTap: () {
                  _searchCtrl.clear();
                  vm.setQuery('');
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

  Widget _buildArchiveStrip(BuildContext context, ChatListViewModel vm) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed(AppRoutes.archived);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            const Icon(Icons.archive_outlined, color: AppColors.dim, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text('Archived', style: AppFonts.body(size: 14, color: AppColors.dim))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.panel2, borderRadius: BorderRadius.circular(100)),
              child: Text('${vm.archivedCount}', style: AppFonts.body(size: 12, color: AppColors.faint)),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmArchive(BuildContext context, ChatListViewModel vm, Convo c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Archive chat?', style: AppFonts.display(size: 17)),
        content: Text(
          'Move "${c.title}" to Archived? You can move it back to chats any time.',
          style: AppFonts.body(size: 13.5, color: AppColors.dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppFonts.body(size: 14, color: AppColors.dim)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Archive', style: AppFonts.body(size: 14, weight: FontWeight.w600, color: AppColors.teal)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      vm.archive(c.id);
      _toast(context, 'Archived "${c.title}"');
    }
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
