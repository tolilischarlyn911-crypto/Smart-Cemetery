import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class GraveMapMarker extends StatelessWidget {
  const GraveMapMarker({super.key, required this.color, this.size = 40});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size, size * 1.1),
    painter: GraveMapMarkerPainter(color),
  );

  static Future<Uint8List> png(Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(2);
    GraveMapMarkerPainter(color).paint(canvas, const Size(40, 44));
    final picture = recorder.endRecording();
    final image = await picture.toImage(80, 88);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    if (data == null) throw StateError('Could not draw the tombstone marker.');
    return data.buffer.asUint8List();
  }
}

class GraveMapMarkerPainter extends CustomPainter {
  const GraveMapMarkerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 44);
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawOval(const Rect.fromLTWH(4, 36, 32, 5), shadow);
    final outline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final stone = Path()
      ..moveTo(7, 34)
      ..lineTo(7, 18)
      ..arcToPoint(const Offset(33, 18), radius: const Radius.circular(13))
      ..lineTo(33, 34)
      ..close();
    canvas.drawPath(stone, Paint()..color = color);
    canvas.drawPath(stone, outline);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 32, 32, 7),
        const Radius.circular(2),
      ),
      Paint()..color = color,
    );
    canvas.drawRect(
      const Rect.fromLTWH(18, 14, 4, 16),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      const Rect.fromLTWH(14, 18, 12, 4),
      Paint()..color = Colors.white,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GraveMapMarkerPainter oldDelegate) =>
      oldDelegate.color != color;
}
