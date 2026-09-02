import 'package:flutter/material.dart';

// ==============================================================
// TOMBSTONE ICON
// Custom-painted outline icon replicating the mock-up logo:
// a rounded headstone with a cross and two leaves at its base.
// ==============================================================

class TombstoneIcon extends StatelessWidget {
  const TombstoneIcon({super.key, this.size = 96, this.color = Colors.white});

  /// Width and height of the square canvas.
  final double size;

  /// Outline color.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _TombstonePainter(color),
    );
  }
}

class _TombstonePainter extends CustomPainter {
  _TombstonePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width; // square canvas

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // ---------- Headstone slab (rounded top) ----------
    final stone = Path()
      ..moveTo(s * 0.24, s * 0.66)
      ..lineTo(s * 0.24, s * 0.34)
      ..arcToPoint(
        Offset(s * 0.76, s * 0.34),
        radius: Radius.circular(s * 0.26),
        clockwise: true,
      )
      ..lineTo(s * 0.76, s * 0.66);
    canvas.drawPath(stone, paint);

    // ---------- Ground line under the stone ----------
    canvas.drawLine(
      Offset(s * 0.12, s * 0.72),
      Offset(s * 0.88, s * 0.72),
      paint,
    );

    // ---------- Cross ----------
    canvas.drawLine(
      // vertical bar
      Offset(s * 0.50, s * 0.16),
      Offset(s * 0.50, s * 0.58),
      paint,
    );
    canvas.drawLine(
      // horizontal bar
      Offset(s * 0.38, s * 0.26),
      Offset(s * 0.62, s * 0.26),
      paint,
    );

    // ---------- Left leaf ----------
    final leftLeaf = Path()
      ..moveTo(s * 0.22, s * 0.69)
      ..quadraticBezierTo(s * 0.06, s * 0.62, s * 0.09, s * 0.46)
      ..quadraticBezierTo(s * 0.17, s * 0.52, s * 0.22, s * 0.69)
      ..close();
    canvas.drawPath(leftLeaf, paint);

    // ---------- Right leaf (mirror image) ----------
    final rightLeaf = Path()
      ..moveTo(s * 0.78, s * 0.69)
      ..quadraticBezierTo(s * 0.94, s * 0.62, s * 0.91, s * 0.46)
      ..quadraticBezierTo(s * 0.83, s * 0.52, s * 0.78, s * 0.69)
      ..close();
    canvas.drawPath(rightLeaf, paint);
  }

  @override
  bool shouldRepaint(covariant _TombstonePainter oldDelegate) =>
      oldDelegate.color != color;
}
