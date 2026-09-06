import 'package:flutter/material.dart';

import '../theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrbitColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                'assets/brand/orbit_logo.png',
                width: 116,
                height: 116,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Orbit',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                valueColor: AlwaysStoppedAnimation(
                  Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbitMark extends StatelessWidget {
  final double size;
  final Color color;
  const _OrbitMark({this.size = 96, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _OrbitMarkPainter(color)),
    );
  }
}

class _OrbitMarkPainter extends CustomPainter {
  final Color color;
  _OrbitMarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final planet = Paint()..color = color;
    canvas.drawCircle(c, size.width * 0.22, planet);

    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 0.92,
        height: size.width * 0.44,
      ),
      ringPaint,
    );

    canvas.drawCircle(Offset(size.width * 0.46, 0), size.width * 0.06, planet);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbitMarkPainter old) => old.color != color;
}

class OrbitMark extends StatelessWidget {
  final double size;
  final Color color;
  const OrbitMark({super.key, this.size = 96, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => _OrbitMark(size: size, color: color);
}
