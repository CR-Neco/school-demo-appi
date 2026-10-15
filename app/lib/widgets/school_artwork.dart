import 'package:flutter/material.dart';

/// Original geometric campus illustration. Deliberately not a depiction of PMG.
class SchoolArtwork extends StatelessWidget {
  const SchoolArtwork({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Stilisierter Schulcampus, Symbolbild',
    child: const CustomPaint(painter: _CampusPainter(), child: SizedBox.expand()),
  );
}

class _CampusPainter extends CustomPainter {
  const _CampusPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 600, size.height / 360);
    final paint = Paint();
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 600, 360),
      paint
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF263A60), Color(0xFF54698D)],
        ).createShader(const Rect.fromLTWH(0, 0, 600, 360)),
    );
    paint.shader = null;
    canvas.drawCircle(
      const Offset(465, 90),
      63,
      paint..color = const Color(0xFFF9BD82),
    );
    canvas.drawOval(
      const Rect.fromLTWH(-50, 290, 740, 180),
      paint..color = const Color(0xFF243D3B),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(100, 150, 330, 160),
        const Radius.circular(4),
      ),
      paint..color = const Color(0xFFDDD8CB),
    );
    canvas.drawRect(
      const Rect.fromLTWH(110, 138, 310, 18),
      paint..color = const Color(0xFF9AAAB8),
    );
    canvas.drawRect(
      const Rect.fromLTWH(325, 110, 160, 200),
      paint..color = const Color(0xFFF3ECE0),
    );
    canvas.drawRect(
      const Rect.fromLTWH(318, 100, 174, 14),
      paint..color = const Color(0xFFB4B9B9),
    );
    for (var x = 128; x < 300; x += 45) {
      for (var y = 180; y < 280; y += 45) {
        canvas.drawRect(
          Rect.fromLTWH(x.toDouble(), y.toDouble(), 25, 28),
          paint..color = const Color(0xFF7D9EAB),
        );
        canvas.drawRect(
          Rect.fromLTWH(x.toDouble(), y + 14.0, 25, 2),
          paint..color = const Color(0xFFDDD8CB),
        );
      }
    }
    for (var x = 347; x < 460; x += 40) {
      canvas.drawRect(
        Rect.fromLTWH(x.toDouble(), 145, 22, 65),
        paint..color = const Color(0xFF8AA8AF),
      );
    }
    canvas.drawRect(
      const Rect.fromLTWH(372, 245, 60, 65),
      paint..color = const Color(0xFF274B5D),
    );
    canvas.drawPath(
      Path()
        ..moveTo(372, 310)
        ..lineTo(432, 310)
        ..lineTo(520, 360)
        ..lineTo(290, 360)
        ..close(),
      paint..color = const Color(0xFFB4AAA0),
    );
    for (final tree in [const Offset(65, 245), const Offset(530, 260)]) {
      canvas.drawRect(
        Rect.fromLTWH(tree.dx - 4, tree.dy, 8, 75),
        paint..color = const Color(0xFF8D705C),
      );
      canvas.drawCircle(tree, 40, paint..color = const Color(0xFF6D9B7F));
      canvas.drawCircle(
        Offset(tree.dx - 16, tree.dy + 8),
        25,
        paint..color = const Color(0xFF7BAC8D),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
