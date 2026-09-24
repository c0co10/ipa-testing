import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game_models.dart';

class GamePainter extends CustomPainter {
  GamePainter(this.state);

  final GameState state;

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawSun(canvas, size);
    _drawClouds(canvas, size);
    for (final platform in state.platforms) {
      _drawPlatform(canvas, platform);
    }
    _drawPlayer(canvas);
  }

  void _drawSky(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF6EC6FF), Color(0xFFCFEFFF)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _drawSun(Canvas canvas, Size size) {
    final center = Offset(size.width - 85, 92);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF59D),
          const Color(0xFFFFD54F).withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 74));
    canvas.drawCircle(center, 74, glow);
    canvas.drawCircle(center, 32, Paint()..color = const Color(0xFFFFE082));
  }

  void _drawClouds(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.85);
    for (var i = 0; i < 7; i++) {
      final xBase = ((i * 137 + 61) % 113) / 113.0;
      final drift = (state.cloudPhase * (14.0 + i * 2.0)) %
          (size.width + 240);
      final x = xBase * (size.width + 240) + drift - 120;
      final y = size.height * (0.1 +
          ((i * 241 + 37) % 83) / 90.0) -
          state.shift * (0.22 + 0.05 * i);
      final scale = 0.6 + ((i * 7) % 5) / 5.0;
      _drawCloud(canvas, Offset(x, y), scale, paint);
    }
  }

  void _drawCloud(Canvas canvas, Offset pos, double scale, Paint paint) {
    final s = scale * 26.0;
    canvas.drawOval(
      Rect.fromCenter(center: pos, width: s * 2.6, height: s * 0.9),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: pos + Offset(-s * 0.85, -s * 0.18),
        width: s * 1.7,
        height: s * 0.9,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: pos + Offset(s * 0.85, -s * 0.12),
        width: s * 1.8,
        height: s * 0.95,
      ),
      paint,
    );
  }

  void _drawPlatform(Canvas canvas, DoodlePlatform platform) {
    final top = platform.moving
        ? const Color(0xFF4FC3F7)
        : const Color(0xFF66BB6A);
    final bottom = platform.moving
        ? const Color(0xFF0288D1)
        : const Color(0xFF2E7D32);
    final screenY = platform.y - state.shift;
    final rect = Rect.fromLTWH(
      platform.x,
      screenY,
      kPlatformWidth,
      kPlatformHeight,
    );
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 3, rect.top + 2, rect.width - 6, 4),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white.withOpacity(0.35),
    );
  }

  void _drawPlayer(Canvas canvas) {
    final p = state.player;
    final legSwing = (p.vy / 900.0).clamp(-1.0, 1.0);
    final sy = 1.0 - (p.vy / 2400.0).clamp(-0.10, 0.10);
    final center = Offset(p.x + kPlayerWidth / 2, p.y + kPlayerHeight / 2);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(p.facingRight ? 1.0 : -1.0, sy);

    final darkGreen = Paint()..color = const Color(0xFF2E7D32);
    final legPaint = Paint()
      ..color = const Color(0xFF1B5E20)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final ankle = 13.0 * legSwing;
    canvas.drawLine(Offset(-7, 13), Offset(-13, 14 + ankle), legPaint);
    canvas.drawLine(Offset(7, 13), Offset(13, 14 - ankle), legPaint);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, 1), width: 30, height: 28),
      Paint()..color = const Color(0xFF43A047),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, 6), width: 20, height: 14),
      Paint()..color = const Color(0xFF81C784),
    );

    final eyePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(-6, -4), 5, eyePaint);
    canvas.drawCircle(Offset(6, -4), 5, eyePaint);
    canvas.drawCircle(Offset(-6, -4), 2.1, darkGreen);
    canvas.drawCircle(Offset(6, -4), 2.1, darkGreen);

    canvas.drawCircle(Offset(0, 0), 2.6, darkGreen);
    final mouth = Paint()
      ..color = const Color(0xFF1B5E20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(0, 3), width: 10, height: 5),
      0.15 * math.pi,
      0.7 * math.pi,
      false,
      mouth,
    );

    canvas.drawLine(Offset(0, -13), Offset(0, -24), legPaint);
    canvas.drawCircle(Offset(0, -26), 4, Paint()..color = const Color(0xFF0288D1));
    canvas.drawCircle(
      Offset(0, -26),
      1.6,
      Paint()..color = Colors.white.withOpacity(0.6),
    );

    canvas.drawLine(Offset(-13, -2), Offset(-17, 4), legPaint);
    canvas.drawLine(Offset(13, -2), Offset(17, 4), legPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}