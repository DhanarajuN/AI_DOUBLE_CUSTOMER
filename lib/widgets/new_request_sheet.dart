import 'package:flutter/material.dart';
import '../data/scripts_data.dart';
import '../theme/app_theme.dart';

/// "New request" bottom sheet — pick a category to start a fresh AI-guided
/// intake conversation (mirrors openNewChat()/startIntake()).
Future<String?> showNewRequestSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.panel,
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
              ...kCategoryMeta.entries.map((e) {
                final key = e.key;
                final meta = e.value;
                return InkWell(
                  onTap: () => Navigator.pop(ctx, key),
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
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: meta.gradient),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(meta.icon, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(meta.title, style: AppFonts.body(size: 14, weight: FontWeight.w600)),
                              const SizedBox(height: 1),
                              Text(meta.subtitle, style: AppFonts.body(size: 12, color: AppColors.dim)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}
