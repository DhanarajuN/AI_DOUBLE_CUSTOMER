import 'package:flutter/material.dart';
import '../services/librechat_service.dart';
import '../theme/app_theme.dart';

/// "New request" bottom sheet — lists agents fetched live from the
/// LibreChat backend (see [LibreChatService.fetchAgents]) and returns the
/// tapped agent's raw JSON, or null if the sheet is dismissed.
Future<Map<String, dynamic>?> showNewRequestSheet(BuildContext context) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    backgroundColor: AppColors.panel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.line2, borderRadius: BorderRadius.circular(2)),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('New request', style: AppFonts.display(size: 20)),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('What do you need help with?', style: AppFonts.body(size: 13, color: AppColors.dim)),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: LibreChatService.fetchAgents(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.teal),
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      debugPrint('[LibreChat] new_request_sheet fetchAgents error: ${snapshot.error}');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Could not load agents. Try again later.',
                          style: AppFonts.body(size: 13, color: AppColors.dim),
                        ),
                      );
                    }
                    final agents = snapshot.data ?? const [];
                    if (agents.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text('No agents available.', style: AppFonts.body(size: 13, color: AppColors.dim)),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: agents.length,
                      itemBuilder: (context, index) {
                        final agent = agents[index];
                        final name = agent['name'] as String? ?? 'Untitled agent';
                        final description = agent['description'] as String? ?? '';
                        return InkWell(
                          onTap: () => Navigator.pop(ctx, agent),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 9),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: AppColors.panel,
                              border: Border.all(color: AppColors.line),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _AgentAvatar(avatar: agent['avatar'] as Map<String, dynamic>?),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: AppFonts.body(size: 14, weight: FontWeight.w600)),
                                      if (description.isNotEmpty) ...[
                                        const SizedBox(height: 1),
                                        Text(description, style: AppFonts.body(size: 12, color: AppColors.dim)),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Renders an agent's `avatar` field (`{"filepath": "pi-sparkles", "source":
/// "gosure-icon"}`) as a gradient icon tile. The backend only ever sends
/// that one icon reference (or omits avatar entirely) — map known
/// filepaths to a Flutter icon and fall back to a generic bot icon.
class _AgentAvatar extends StatelessWidget {
  final Map<String, dynamic>? avatar;
  const _AgentAvatar({required this.avatar});

  @override
  Widget build(BuildContext context) {
    final filepath = avatar?['filepath'] as String?;
    final icon = switch (filepath) {
      'pi-sparkles' => Icons.auto_awesome,
      _ => Icons.smart_toy_outlined,
    };
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppColors.tealGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}
