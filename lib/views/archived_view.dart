import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/convo_repository.dart';
import '../repositories/pro_repository.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../viewmodels/archived_view_model.dart';
import '../widgets/chat_row.dart';

class ArchivedView extends StatelessWidget {
  const ArchivedView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => ArchivedViewModel(
        ctx.read<ConvoRepository>(),
        ctx.read<ProRepository>(),
      ),
      child: const _ArchivedBody(),
    );
  }
}

class _ArchivedBody extends StatelessWidget {
  const _ArchivedBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ArchivedViewModel>();
    return Scaffold(
      backgroundColor: AppColors.appBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(6, 14, 14, 12),
              decoration: const BoxDecoration(
                color: AppColors.appSurfaceColor,
                border: Border(bottom: BorderSide(color: AppColors.appBorderColor)),
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
                  for (final c in vm.archivedConvos)
                    ChatRow(
                      convo: c,
                      pro: vm.proFor(c),
                      onTap: () {
                        vm.openConvo(c.id);
                        Navigator.of(context).pushNamed(AppRoutes.chatThread, arguments: c.id);
                      },
                      onUnarchive: () {
                        vm.unarchive(c.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Moved "${c.title}" to chats'),
                            behavior: SnackBarBehavior.floating,
                          ),
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
