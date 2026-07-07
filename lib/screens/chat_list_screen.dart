import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_row.dart';
import '../widgets/new_request_sheet.dart';
import 'archived_screen.dart';
import 'chat_thread_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

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
                      _buildSearchBar(context),
                      _buildArchiveStrip(context, state),
                      for (final c in state.visibleConvos)
                        ChatRow(
                          convo: c,
                          pro: c.proId != null ? state.pros[c.proId] : null,
                          onTap: () {
                            state.openConvo(c.id);
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ChatThreadScreen()),
                            );
                          },
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
                          state.startIntake(category);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ChatThreadScreen()),
                          );
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
            onPressed: () => _toast(context, 'Search'),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.dim),
            onPressed: () => _toast(context, 'Menu'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: InkWell(
        onTap: () => _toast(context, 'Search chats'),
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.panel2,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 16, color: AppColors.faint),
              const SizedBox(width: 9),
              Text('Search or ask AI Double…', style: AppFonts.body(size: 13.5, color: AppColors.faint)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArchiveStrip(BuildContext context, AppState state) {
    return InkWell(
      onTap: () {
        state.openArchived();
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ArchivedScreen()));
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
              child: Text('${state.archivedCount}', style: AppFonts.body(size: 12, color: AppColors.faint)),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF1A2B24)),
    );
  }
}
