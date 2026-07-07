import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_row.dart';
import 'chat_thread_screen.dart';

class ArchivedScreen extends StatelessWidget {
  const ArchivedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppColors.app,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(6, 14, 14, 12),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Archived', style: AppFonts.display(size: 19)),
                      Text('PAST CONVERSATIONS', style: AppFonts.mono(size: 10, letterSpacing: 1)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final c in state.archivedConvos)
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
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
