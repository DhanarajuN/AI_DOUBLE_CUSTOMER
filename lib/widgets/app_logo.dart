import 'package:flutter/material.dart';

/// The app's brand mark: a solid circle overlapping a ring circle, on a
/// light squircle tile. Matches assets/branding/app_icon.svg and
/// assets/icon/icon.png in AI_DOUBLE_BUSINESS (same brand, kept in sync by
/// hand across both apps) — keep them consistent if this changes.
class AppLogoMark extends StatelessWidget {
  final double size;
  const AppLogoMark({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AppLogoPainter()),
    );
  }
}

class _AppLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    const paper = Color(0xFFEEF1F5);
    const chrome = Color(0xFF0C1B31);

    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0.2, 0.2, 99.6, 99.6), const Radius.circular(22)),
      Paint()..color = paper,
    );

    canvas.drawCircle(const Offset(38.18, 50), 27.54, Paint()..color = chrome);
    canvas.drawCircle(const Offset(61.82, 50), 27.54, Paint()..color = chrome);
    canvas.drawCircle(const Offset(61.82, 50), 17.9, Paint()..color = paper);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
