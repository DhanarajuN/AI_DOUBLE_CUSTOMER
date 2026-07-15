import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/auth_repository.dart';
import '../services/librechat_service.dart';
import '../theme/app_theme.dart';

/// Key stamped on a synthetic sheet entry for an ACTIVE_AGENTS name that
/// has no matching LibreChat agent — shown dimmed and non-tappable.
const _notConfiguredKey = '_notConfigured';

/// Builds the sheet's agent list from [activeAgentNames] (from
/// AuthRepository.fetchModuleConstants — /api/v1/module-constants'
/// ACTIVE_AGENTS, comma-separated, e.g. "Insurance,Education,Home
/// Services,Healthcare,Integra - Claims"), in that order. Every name is
/// shown even if [agents] (LibreChat's list) has no match for it — those
/// entries are marked [_notConfiguredKey] so they render dimmed and
/// non-tappable instead of opening a chat. Null (not loaded/failed) or
/// empty (key missing/blank) activeAgentNames falls back to showing every
/// LibreChat agent unfiltered.
List<Map<String, dynamic>> _buildSheetAgents(List<Map<String, dynamic>> agents, List<String>? activeAgentNames) {
  debugPrint('[NewRequestSheet] activeAgentNames from AuthRepository: $activeAgentNames');
  debugPrint('[NewRequestSheet] agent names from LibreChat: ${agents.map((a) => a['name']).toList()}');
  if (activeAgentNames == null || activeAgentNames.isEmpty) {
    debugPrint('[NewRequestSheet] no active-agent filter — showing all ${agents.length} agents');
    return agents;
  }
  final byName = {for (final a in agents) ((a['name'] as String?) ?? '').trim().toLowerCase(): a};
  final result = activeAgentNames.map((name) {
    final match = byName[name.trim().toLowerCase()];
    if (match != null) return match;
    return <String, dynamic>{'name': name, _notConfiguredKey: true};
  }).toList();
  debugPrint('[NewRequestSheet] built ${result.length} sheet entries '
      '(${result.where((a) => a[_notConfiguredKey] != true).length} matched, '
      '${result.where((a) => a[_notConfiguredKey] == true).length} not configured)');
  return result;
}

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
                  future: LibreChatService.fetchAgents().then(
                    (agents) => _buildSheetAgents(agents, context.read<AuthRepository>().activeAgentNames),
                  ),
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
                        final notConfigured = agent[_notConfiguredKey] == true;
                        final name = agent['name'] as String? ?? 'Untitled agent';
                        final description = notConfigured ? 'Not configured yet' : (agent['description'] as String? ?? '');
                        return InkWell(
                          onTap: notConfigured ? null : () => Navigator.pop(ctx, agent),
                          borderRadius: BorderRadius.circular(12),
                          child: Opacity(
                            opacity: notConfigured ? 0.5 : 1,
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
