import 'package:flutter/material.dart';

/// Google "G" mark — giriş butonları için (Material `g_mobiledata` yerine).
///
/// Klasik 4 renkli Super G (Sign in with Google stil path, viewBox 0 0 48 48).
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

  // Google brand colors.
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    const vb = 48.0;
    final s = size.shortestSide / vb;
    canvas.save();
    canvas.scale(s, s);

    // Yellow base (ring + right bar area) — flat-icon / Material G paths.
    canvas.drawPath(_yellowPath(), Paint()..color = _yellow);
    canvas.drawPath(_redPath(), Paint()..color = _red);
    canvas.drawPath(_greenPath(), Paint()..color = _green);
    canvas.drawPath(_bluePath(), Paint()..color = _blue);

    canvas.restore();
  }

  static Path _yellowPath() {
    final p = Path()..moveTo(43.611, 20.083);
    p
      ..lineTo(42, 20.083)
      ..lineTo(42, 20)
      ..lineTo(24, 20)
      ..lineTo(24, 28)
      ..lineTo(35.303, 28)
      ..relativeCubicTo(-1.649, 4.657, -6.08, 8, -11.303, 8)
      ..relativeCubicTo(-6.627, 0, -12, -5.373, -12, -12)
      ..relativeCubicTo(0, -6.627, 5.373, -12, 12, -12)
      ..relativeCubicTo(3.059, 0, 5.842, 1.154, 7.961, 3.039)
      ..relativeLineTo(5.657, -5.657)
      ..cubicTo(34.046, 6.053, 29.268, 4, 24, 4)
      ..cubicTo(12.955, 4, 4, 12.955, 4, 24)
      ..relativeCubicTo(0, 11.045, 8.955, 20, 20, 20)
      ..relativeCubicTo(11.045, 0, 20, -8.955, 20, -20)
      ..cubicTo(44, 22.659, 43.862, 21.35, 43.611, 20.083)
      ..close();
    return p;
  }

  static Path _redPath() {
    final p = Path()..moveTo(6.306, 14.691);
    p
      ..relativeLineTo(6.571, 4.819)
      ..cubicTo(14.655, 15.108, 18.961, 12, 24, 12)
      ..relativeCubicTo(3.059, 0, 5.842, 1.154, 7.961, 3.039)
      ..relativeLineTo(5.657, -5.657)
      ..cubicTo(34.046, 6.053, 29.268, 4, 24, 4)
      ..cubicTo(16.318, 4, 9.656, 8.337, 6.306, 14.691)
      ..close();
    return p;
  }

  static Path _greenPath() {
    final p = Path()..moveTo(24, 44);
    p
      ..relativeCubicTo(5.166, 0, 9.86, -1.977, 13.409, -5.192)
      ..relativeLineTo(-6.19, -5.238)
      ..cubicTo(29.211, 35.091, 26.715, 36, 24, 36)
      ..relativeCubicTo(-5.202, 0, -9.619, -3.317, -11.283, -7.946)
      ..relativeLineTo(-6.522, 5.025)
      ..cubicTo(9.505, 39.556, 16.227, 44, 24, 44)
      ..close();
    return p;
  }

  static Path _bluePath() {
    final p = Path()..moveTo(43.611, 20.083);
    p
      ..lineTo(42, 20.083)
      ..lineTo(42, 20)
      ..lineTo(24, 20)
      ..lineTo(24, 28)
      ..lineTo(35.303, 28)
      ..relativeCubicTo(-0.792, 2.237, -2.231, 4.166, -4.087, 5.571)
      ..relativeCubicTo(0.001, -0.001, 0.002, -0.001, 0.003, -0.002)
      ..relativeLineTo(6.19, 5.238)
      ..cubicTo(36.971, 39.205, 44, 34, 44, 24)
      ..cubicTo(44, 22.659, 43.862, 21.35, 43.611, 20.083)
      ..close();
    return p;
  }

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
