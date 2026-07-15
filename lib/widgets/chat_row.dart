import 'package:flutter/material.dart';
import '../models/convo.dart';
import '../models/pro.dart';
import '../theme/app_theme.dart';

class ChatRow extends StatelessWidget {
  final Convo convo;
  final Pro? pro; // resolved by caller's ViewModel from ProRepository.getById(convo.proId)
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// When set, shows a trailing "move to chats" action (used by the
  /// Archived screen to unarchive a conversation). Left null elsewhere.
  final VoidCallback? onUnarchive;

  const ChatRow({
    super.key,
    required this.convo,
    required this.onTap,
    this.pro,
    this.onLongPress,
    this.onUnarchive,
  });

  @override
  Widget build(BuildContext context) {
    final unread = convo.unread > 0;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _avatar(),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(bottom: 11),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.appBorderColor)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  convo.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.body(size: 15.5, weight: FontWeight.w600),
                                ),
                              ),
                              if (convo.isAI) ...[
                                const SizedBox(width: 5),
                                const Text('✓', style: TextStyle(color: AppColors.appPrimaryColor, fontSize: 12)),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          convo.time,
                          style: AppFonts.body(
                            size: 11,
                            color: unread ? AppColors.appSuccessColor : AppColors.appTextMutedColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (convo.lastFromMe) ...[
                                const Text('✓✓', style: TextStyle(color: AppColors.appSuccessColor, fontSize: 12)),
                                const SizedBox(width: 5),
                              ],
                              Expanded(
                                child: Text(
                                  convo.preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.body(size: 13, color: AppColors.appTextSecondaryColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            height: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.appSuccessColor,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              '${convo.unread}',
                              style: const TextStyle(
                                color: AppColors.appOnPrimaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (onUnarchive != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.move_to_inbox_outlined, color: AppColors.appTextSecondaryColor, size: 20),
                tooltip: 'Move to chats',
                onPressed: onUnarchive,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _avatar() {
    if (convo.isAI) {
      return Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(
          gradient: AppColors.appPrimaryGradient,
          shape: BoxShape.circle,
        ),
        child: Stack(
          children: [
            const Center(
              child: Text('AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17)),
            ),
            Positioned(
              bottom: -1,
              right: -1,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.appSecondaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.appBackgroundColor, width: 2.5),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final gradient = pro?.gradient ?? const [AppColors.appPrimaryColor, AppColors.appPrimaryDarkColor];
    final initials = pro?.initials ?? '';
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17),
      ),
    );
  }
}
