import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DayMarkWidget extends StatelessWidget {
  final String label;
  const DayMarkWidget({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.appSurfaceVariantColor,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(label, style: AppFonts.mono(size: 10.5, letterSpacing: 0.6)),
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});
  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.appChatBubbleOtherColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(11),
            topRight: Radius.circular(11),
            bottomLeft: Radius.circular(3),
            bottomRight: Radius.circular(11),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                final t = ((_ctrl.value - i * 0.15) % 1.0 + 1.0) % 1.0;
                final lift = (t < 0.3) ? (t / 0.3) : (t < 0.6 ? 1 - (t - 0.3) / 0.3 : 0.0);
                return Transform.translate(
                  offset: Offset(0, -3 * lift),
                  child: Opacity(
                    opacity: 0.3 + 0.7 * lift,
                    child: Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(color: AppColors.appTextSecondaryColor, shape: BoxShape.circle),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
