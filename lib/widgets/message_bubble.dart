import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/pro.dart';
import '../theme/app_theme.dart';
import 'pro_card.dart';

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
          color: AppColors.panel2,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(label, style: AppFonts.mono(size: 10.5, letterSpacing: 0.6)),
      ),
    );
  }
}

class TextBubble extends StatelessWidget {
  final ChatMessage message;
  const TextBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final me = message.isMe;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(11, 8, 11, 6),
        decoration: BoxDecoration(
          color: me ? AppColors.mine : AppColors.other,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(11),
            topRight: const Radius.circular(11),
            bottomLeft: Radius.circular(me ? 11 : 3),
            bottomRight: Radius.circular(me ? 3 : 11),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(message.text, style: AppFonts.body(size: 14)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.time,
                  style: AppFonts.body(
                    size: 9.5,
                    color: me ? Colors.white.withOpacity(0.45) : AppColors.faint,
                  ),
                ),
                if (me) ...[
                  const SizedBox(width: 3),
                  const Text('✓✓', style: TextStyle(color: AppColors.green, fontSize: 9.5)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProListBubble extends StatelessWidget {
  final ChatMessage message;
  final Map<String, Pro> pros;
  final void Function(String proId) onTapPro;
  const ProListBubble({
    super.key,
    required this.message,
    required this.pros,
    required this.onTapPro,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
        decoration: const BoxDecoration(
          color: AppColors.other,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(11),
            topRight: Radius.circular(11),
            bottomLeft: Radius.circular(3),
            bottomRight: Radius.circular(11),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.text, style: AppFonts.body(size: 14)),
            Container(
              margin: const EdgeInsets.only(top: 5),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.28),
                borderRadius: BorderRadius.circular(10),
                border: const Border(left: BorderSide(color: AppColors.gold, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '◆ MATCHED · 1.2S',
                    style: AppFonts.mono(size: 8.5, color: AppColors.gold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  for (final id in message.proIds)
                    if (pros[id] != null)
                      ProCard(pro: pros[id]!, onTap: () => onTapPro(id)),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(message.time, style: AppFonts.body(size: 9.5, color: AppColors.faint)),
          ],
        ),
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
        decoration: const BoxDecoration(
          color: AppColors.other,
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
                      decoration: const BoxDecoration(color: AppColors.dim, shape: BoxShape.circle),
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
