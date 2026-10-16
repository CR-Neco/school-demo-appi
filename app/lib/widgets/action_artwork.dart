import 'package:flutter/material.dart';

/// Original local geometric illustrations, matching the existing campus artwork.
/// No remote image, logo or runtime asset download.
class ActionArtwork extends StatelessWidget {
  const ActionArtwork(this.kind, {super.key});
  final String kind;
  @override
  Widget build(BuildContext context) => Semantics(
    label: switch (kind) { 'kiosk' => 'Illustration eines Kiosks', 'reading' => 'Illustration eines Leseabends',
      'sports' => 'Illustration eines Sportfests', _ => 'Illustration eines Verkaufsstands' },
    image: true,
    child: ClipRRect(borderRadius: BorderRadius.circular(22), child: CustomPaint(
      painter: _ActionPainter(kind), child: SizedBox.expand(child: Align(
        alignment: const Alignment(0.6, 0),
        child: Icon(switch (kind) { 'kiosk' => Icons.coffee_rounded, 'reading' => Icons.menu_book_rounded,
          'sports' => Icons.sports_soccer_rounded, _ => Icons.cake_rounded },
          color: const Color(0xFF172D37), size: 66),
      )),
    )),
  );
}

class _ActionPainter extends CustomPainter {
  const _ActionPainter(this.kind);
  final String kind;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 600, size.height / 260);
    final paint = Paint();
    final background = switch (kind) { 'kiosk' => const Color(0xFFDDF49C), 'reading' => const Color(0xFFD5DEF6),
      'sports' => const Color(0xFFC9E5CF), _ => const Color(0xFFF9D8B9) };
    canvas.drawRect(const Rect.fromLTWH(0, 0, 600, 260), paint..color = background);
    canvas.drawCircle(const Offset(490, 55), 110, paint..color = Colors.white.withValues(alpha: 0.35));
    canvas.drawOval(const Rect.fromLTWH(-50, 220, 730, 100), paint..color = const Color(0xFF172D37).withValues(alpha: 0.12));
    if (kind == 'reading') {
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(80, 65, 230, 145), const Radius.circular(12)),
        paint..color = const Color(0xFF172D37));
      for (var i = 0; i < 7; i++) {
        canvas.drawRect(Rect.fromLTWH(95 + i * 28, 85, 19, 105), paint..color = i.isEven ? const Color(0xFFF9D8B9) : const Color(0xFFDDF49C));
      }
    } else if (kind == 'sports') {
      paint..color = const Color(0xFF659A77)..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(55, 55, 285, 155), const Radius.circular(10)), paint);
      paint..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 4;
      canvas.drawRect(const Rect.fromLTWH(73, 72, 248, 120), paint);
      canvas.drawLine(const Offset(197, 72), const Offset(197, 192), paint);
      canvas.drawCircle(const Offset(197, 132), 29, paint);
      paint.style = PaintingStyle.fill;
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(75, 100, 245, 130), const Radius.circular(10)),
        paint..color = const Color(0xFFF7F3E9));
      canvas.drawRect(const Rect.fromLTWH(90, 130, 215, 55), paint..color = const Color(0xFF172D37));
      canvas.drawPath(Path()..moveTo(60, 100)..lineTo(100, 50)..lineTo(295, 50)..lineTo(335, 100)..close(),
        paint..color = const Color(0xFF172D37));
      for (var i = 0; i < 5; i++) {
        canvas.drawRect(Rect.fromLTWH(75 + i * 49, 100, 24, 20), paint..color = const Color(0xFF172D37));
      }
      canvas.drawRect(const Rect.fromLTWH(90, 200, 215, 8), paint..color = background);
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _ActionPainter oldDelegate) => oldDelegate.kind != kind;
}
