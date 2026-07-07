import 'package:flutter/material.dart';
import '../models/convo.dart';
import '../models/pro.dart';
import '../theme/app_theme.dart';

class ChatRow extends StatelessWidget {
  final Convo convo;
  final Pro? pro; // resolved by caller from AppState.pros[convo.proId]
  final VoidCallback onTap;
  const ChatRow({super.key, required this.convo, required this.onTap, this.pro});

  @override
  Widget build(BuildContext context) {
    final unread = convo.unread > 0;
    return InkWell(
      onTap: onTap,
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
                  border: Border(bottom: BorderSide(color: AppColors.line)),
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
                                const Text('✓', style: TextStyle(color: AppColors.teal, fontSize: 12)),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          convo.time,
                          style: AppFonts.body(
                            size: 11,
                            color: unread ? AppColors.green : AppColors.faint,
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
                                const Text('✓✓', style: TextStyle(color: AppColors.green, fontSize: 12)),
                                const SizedBox(width: 5),
                              ],
                              Expanded(
                                child: Text(
                                  convo.preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.body(size: 13, color: AppColors.dim),
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
                              color: AppColors.green,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              '${convo.unread}',
                              style: const TextStyle(
                                color: Color(0xFF04120D),
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
          gradient: AppColors.tealGradient,
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
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.app, width: 2.5),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final gradient = pro?.gradient ?? const [AppColors.teal, AppColors.tealDeep];
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
