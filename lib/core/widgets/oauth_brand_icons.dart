import 'package:flutter/material.dart';

/// Google "G" mark — giriş butonları için (Material `g_mobiledata` yerine).
class GoogleLogoMark extends StatelessWidget {
  const GoogleLogoMark({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

/// Apple logo — koyu temada beyaz silüet.
class AppleLogoMark extends StatelessWidget {
  const AppleLogoMark({
    super.key,
    this.size = 20,
    this.color = const Color(0xFFF5F5F7),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AppleLogoPainter(color: color)),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.175;
    final inset = stroke / 2;
    final rect = Rect.fromLTWH(inset, inset, s - stroke, s - stroke);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square;

    // Clockwise from top-right gap of the G.
    ring.color = _red;
    canvas.drawArc(rect, _rad(-45), _rad(95), false, ring);
    ring.color = _yellow;
    canvas.drawArc(rect, _rad(50), _rad(75), false, ring);
    ring.color = _green;
    canvas.drawArc(rect, _rad(125), _rad(75), false, ring);
    ring.color = _blue;
    canvas.drawArc(rect, _rad(200), _rad(115), false, ring);

    final bar = Paint()..color = _blue;
    final cy = s * 0.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.50, cy - stroke / 2, s * 0.40, stroke),
        Radius.circular(stroke / 5),
      ),
      bar,
    );
  }

  static double _rad(double deg) => deg * 3.141592653589793 / 180.0;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AppleLogoPainter extends CustomPainter {
  _AppleLogoPainter({required this.color});

  final Color color;

  /// Simple Icons apple path, viewBox 0 0 24 24.
  @override
  void paint(Canvas canvas, Size size) {
    const vb = 24.0;
    final sx = size.width / vb;
    final sy = size.height / vb;
    canvas.save();
    canvas.scale(sx, sy);

    final leaf = Path()
      ..moveTo(15.53, 3.83)
      ..cubicTo(16.373, 2.818, 16.93, 1.403, 16.775, 0)
      ..cubicTo(15.568, 0.052, 14.113, 0.805, 13.243, 1.818)
      ..cubicTo(12.463, 2.714, 11.789, 4.156, 11.97, 5.532)
      ..cubicTo(13.308, 5.636, 14.685, 4.844, 15.53, 3.83)
      ..close();

    final body = Path()
      ..moveTo(12.152, 6.896)
      ..cubicTo(11.204, 6.896, 9.737, 5.818, 8.192, 5.856)
      ..cubicTo(6.152, 5.883, 4.282, 7.039, 3.231, 8.87)
      ..cubicTo(1.114, 12.545, 2.685, 17.973, 4.75, 20.96)
      ..cubicTo(5.763, 22.414, 6.958, 24.05, 8.542, 23.999)
      ..cubicTo(10.062, 23.934, 10.632, 23.012, 12.477, 23.012)
      ..cubicTo(14.308, 23.012, 14.827, 23.999, 16.437, 23.96)
      ..cubicTo(18.074, 23.934, 19.113, 22.48, 20.113, 21.012)
      ..cubicTo(21.269, 19.324, 21.749, 17.687, 21.775, 17.597)
      ..cubicTo(21.74, 17.584, 18.593, 16.376, 18.555, 12.74)
      ..cubicTo(18.529, 9.7, 21.035, 8.246, 21.152, 8.181)
      ..cubicTo(19.723, 6.091, 17.529, 5.857, 16.762, 5.805)
      ..cubicTo(14.762, 5.649, 13.087, 6.895, 12.152, 6.896)
      ..close();

    final paint = Paint()..color = color;
    canvas.drawPath(leaf, paint);
    canvas.drawPath(body, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AppleLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}
