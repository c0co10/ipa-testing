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
    _drawMountains(canvas, size);
    _drawClouds(canvas, size, 1.0, 0.18, 0.7);
    _drawClouds(canvas, size, 2.0, 0.34, 0.95);

    // World layer is shaken; background stays put.
    canvas.save();
    canvas.translate(state.shakeX, state.shakeY);
    for (final platform in state.platforms) {
      _drawPlatform(canvas, platform);
    }
    _drawParticles(canvas);
    _drawPlayer(canvas);
    canvas.restore();

    _drawBanner(canvas, size);
  }

  void _drawSky(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [GamePalette.skyTop, GamePalette.skyBottom],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _drawSun(Canvas canvas, Size size) {
    final center = Offset(size.width - 85, 92);
    if (center.dy < -60) return;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          GamePalette.sunGlow,
          const Color(0xFFFFD54F).withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 74));
    canvas.drawCircle(center, 74, glow);
    canvas.drawCircle(center, 32, Paint()..color = GamePalette.sunCore);
  }

  /// Soft green mountain silhouettes that slide down slowly as you climb.
  void _drawMountains(Canvas canvas, Size size) {
    final paintFar = Paint()..color = const Color(0xFFA5D6A7).withOpacity(0.55);
    final paintNear = Paint()..color = const Color(0xFF81C784).withOpacity(0.65);

    var baseY = size.height * 0.965 - state.shift * 0.10;
    var baseH = size.height * 0.42;
    if (baseY < -baseH) return;

    for (var i = 0; i < 4; i++) {
      final span = size.width / 4;
      final hScale = 1.0 + ((i * 37) % 5) / 5.0;
      final x = i * span + (size.width * 0.04) * ((i * 17) % 7 - 3) / 3.0;
      final rect = Rect.fromLTWH(x - span / 2, baseY, span, baseH * hScale);
      canvas.drawOval(rect, paintFar);
    }
    baseY = size.height * 0.995 - state.shift * 0.14;
    if (baseY < -baseH) return;
    for (var i = 0; i < 3; i++) {
      final span = size.width / 3.2;
      final hScale = 1.0 + ((i * 29) % 4) / 4.0;
      final x = i * span * 1.05 - size.width * 0.08;
      final rect = Rect.fromLTWH(x - span / 2, baseY, span, baseH * hScale * 0.8);
      canvas.drawOval(rect, paintNear);
    }
  }

  void _drawClouds(
    Canvas canvas,
    Size size,
    double speedMul,
    double parallax,
    double alpha,
  ) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(alpha);
    for (var i = 0; i < 6; i++) {
      final width = size.width + 260.0;
      final xBase = ((i * 137 + 61) % 113) / 113.0;
      final drift =
          (state.time * (10.0 + i * 1.7) * speedMul) % width;
      final x = xBase * width + drift - 130;
      var y = size.height *
              (0.08 + ((i * 241 + 37) % 83) / 96.0) +
              (state.shift.abs()) * parallax * (0.2 + 0.05 * i);
      // Scroll clouds downward slowly with climbing; wrap back to the top.
      final span = size.height + 260.0;
      while (y > span) {
        y -= span;
      }
      final scale = (0.5 + ((i * 7) % 5) / 6.0) * speedMul;
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
    if (platform.isBroken) {
      _drawBrokenPlatform(canvas, platform);
      return;
    }

    final (top, bottom) = switch (platform) {
      _ when platform.moving =>
        (GamePalette.movingTop, GamePalette.movingBottom),
      _ when platform.breakable =>
        (GamePalette.breakableTop, GamePalette.breakableBottom),
      _ => (GamePalette.platformTop, GamePalette.platformBottom),
    };

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

    canvas.save();
    canvas.rotate(platform.rot);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 3, rect.top + 2, rect.width - 6, 3.5),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white.withOpacity(0.3),
    );
    canvas.restore();

    if (platform.breakable) {
      _drawCracks(canvas, rect);
    }

    if (platform.hasSpring) {
      _drawSpring(canvas, rect);
    }
  }

  void _drawBrokenPlatform(Canvas canvas, DoodlePlatform platform) {
    final screenY = platform.y - state.shift;
    final rect = Rect.fromLTWH(
      platform.x,
      screenY,
      kPlatformWidth,
      kPlatformHeight,
    );
    final paint = Paint()
      ..color = GamePalette.breakableBottom.withOpacity(0.55);
    canvas.save();
    canvas.rotate(platform.rot);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      paint,
    );
    canvas.restore();
  }

  void _drawCracks(Canvas canvas, Rect rect) {
    final crack = Paint()
      ..color = const Color(0xFF3E2A18).withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..moveTo(rect.left + rect.width * 0.25, rect.top + rect.height)
      ..lineTo(rect.left + rect.width * 0.32, rect.top + rect.height * 0.5)
      ..lineTo(rect.left + rect.width * 0.24, rect.top)
      ..moveTo(rect.left + rect.width * 0.62, rect.top + rect.height)
      ..lineTo(rect.left + rect.width * 0.56, rect.top + rect.height * 0.55)
      ..lineTo(rect.left + rect.width * 0.66, rect.top);
    canvas.drawPath(path, crack);
  }

  void _drawSpring(Canvas canvas, Rect platformRect) {
    final centerX = platformRect.center.dx;
    final bob = math.sin(state.time * 6 + centerX) * 1.4;
    final springTop = platformRect.top - kSpringHeight + bob;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        centerX - kSpringWidth / 2,
        springTop,
        kSpringWidth,
        kSpringHeight,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [GamePalette.springRed, GamePalette.springDark],
        ).createShader(body.outerRect),
    );
    // Coil rings.
    final ring = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (var i = 0; i < 4; i++) {
      final y = springTop + 4 + i * 4.5;
      canvas.drawArc(
        Rect.fromLTWH(centerX - kSpringWidth / 2, y, kSpringWidth, 6),
        0,
        math.pi,
        false,
        ring,
      );
    }
    // Base plate sitting on the platform.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - kSpringWidth / 2 - 3,
          platformRect.top - 3,
          kSpringWidth + 6,
          4,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = GamePalette.springDark,
    );
  }

  void _drawParticles(Canvas canvas) {
    for (final p in state.particles) {
      final t = p.life / p.maxLife;
      final paint = Paint()
        ..color = p.color.withOpacity((0.9 * t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(p.x, p.y), p.size * t, paint);
    }
  }

  void _drawPlayer(Canvas canvas) {
    final p = state.player;
    final legSwing = (p.vy / 900.0).clamp(-1.0, 1.0);
    final sy = 1.0 - (p.vy / 2400.0).clamp(-0.10, 0.10);
    final lean = (p.vx / kMaxHorizontalSpeed).clamp(-1.0, 1.0) * 0.22;
    final center = Offset(p.x + kPlayerWidth / 2, p.y + kPlayerHeight / 2);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(p.facingRight ? 1.0 : -1.0, 1.0);
    canvas.rotate(lean);
    canvas.scale(1.0, sy);

    final dark = Paint()..color = GamePalette.doodleDark;
    final legPaint = Paint()
      ..color = GamePalette.doodleDeep
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Legs with little shoes.
    final ankle = 13.0 * legSwing;
    canvas.drawLine(Offset(-7, 13), Offset(-13, 14 + ankle), legPaint);
    canvas.drawLine(Offset(7, 13), Offset(13, 14 - ankle), legPaint);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-15, 14 + ankle * 0.8),
        width: 12,
        height: 6,
      ),
      Paint()..color = GamePalette.doodleGreen,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(15, 14 - ankle * 0.8),
        width: 12,
        height: 6,
      ),
      Paint()..color = GamePalette.doodleGreen,
    );

    // Body.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, 1), width: 30, height: 28),
      Paint()..color = GamePalette.doodleGreen,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, -18), width: 16, height: 10),
      Paint()..color = GamePalette.doodleGreen,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, 6), width: 20, height: 14),
      Paint()..color = GamePalette.doodleBelly,
    );

    // Eyes.
    final eyePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(-6, -4), 5, eyePaint);
    canvas.drawCircle(Offset(6, -4), 5, eyePaint);
    canvas.drawCircle(Offset(-6, -4), 2.1, dark);
    canvas.drawCircle(Offset(6, -4), 2.1, dark);

    // Nose + mouth.
    canvas.drawCircle(Offset(0, 0), 2.6, dark);
    final mouth = Paint()
      ..color = GamePalette.doodleDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(0, 3), width: 10, height: 5),
      0.15 * math.pi,
      0.7 * math.pi,
      false,
      mouth,
    );

    // Antenna.
    canvas.drawLine(Offset(0, -21), Offset(0, -31), legPaint);
    canvas.drawCircle(Offset(0, -33), 4, Paint()..color = const Color(0xFF0288D1));
    canvas.drawCircle(
      Offset(0, -33),
      1.6,
      Paint()..color = Colors.white.withOpacity(0.6),
    );

    // Arms.
    canvas.drawLine(Offset(-13, -2), Offset(-17, 4), legPaint);
    canvas.drawLine(Offset(13, -2), Offset(17, 4), legPaint);

    canvas.restore();
  }

  void _drawBanner(Canvas canvas, Size size) {
    if (state.banner == null || state.bannerTimer <= 0) return;
    final t = (state.bannerTimer / 1.4).clamp(0.0, 1.0);
    final painter = TextPainter(
      text: TextSpan(
        text: state.banner,
        style: TextStyle(
          color: Colors.white.withOpacity(t),
          fontSize: 42,
          fontWeight: FontWeight.w900,
          shadows: const [
            Shadow(blurRadius: 12, color: Colors.black38, offset: Offset(0, 3)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset((size.width - painter.width) / 2, size.height * 0.30),
    );
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}