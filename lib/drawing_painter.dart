import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'coin_provider.dart';
import 'line_provider.dart';
import 'obstacle_provider.dart';
import 'player_skin.dart';

/// Renders the complete game world, including background elements,
/// the player avatar, obstacles, coins and drawn platforms.
class DrawingPainter extends CustomPainter {
  DrawingPainter({
    required this.playerPosition,
    required this.lines,
    required this.obstacles,
    required this.coins,
    required this.skin,
    required this.isRestWindow,
    required this.colorBlindFriendly,
    required this.elapsedMs,
    required this.scrollSpeed,
    required this.frameId,
    required this.lineSignature,
  });

  final Offset playerPosition;
  final List<DrawnLine> lines;
  final List<Obstacle> obstacles;
  final List<Coin> coins;
  final PlayerSkin skin;
  final bool isRestWindow;
  final bool colorBlindFriendly;
  final double elapsedMs;
  final double scrollSpeed;
  final int frameId;
  final int lineSignature;
  final Paint _coinHaloPaint =
      Paint()..style = PaintingStyle.stroke..strokeWidth = 2;
  final Paint _coinSparklePaint =
      Paint()..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round;
  final Paint _lineStrokePaint =
      Paint()..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..strokeWidth = 8;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawGround(canvas, size);
    _drawCoins(canvas);
    _drawObstacles(canvas);
    _drawLines(canvas);
    _drawPlayer(canvas);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final backgroundColors = isRestWindow
        ? const [Color(0xFF02131E), Color(0xFF0F2A4E), Color(0xFF34D399)]
        : const [Color(0xFF020617), Color(0xFF0B1220), Color(0xFF1D4ED8)];
    final gradient = LinearGradient(
      colors: backgroundColors,
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [0.0, 0.45, 1.0],
    );
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    _drawAurora(canvas, size);
    _drawStarfield(canvas, size);
    _drawParallaxLayers(canvas, size);
  }

  void _drawStarfield(Canvas canvas, Size size) {
    final double time = elapsedMs / 1000.0;
    final starPaint = Paint()
      ..color = Colors.white.withOpacity(0.12 + 0.08 * math.sin(time * 2.2))
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;

    for (double x = 0; x < size.width + 140; x += 70) {
      final double baseY = (x * 0.35 + time * 40) % (size.height * 0.6);
      final double jitter = math.sin((x + time * 60) * 0.02) * 10;
      canvas.drawPoints(
        ui.PointMode.points,
        [
          Offset((x + time * 50) % (size.width + 120), baseY + 40 + jitter),
          Offset((x * 0.8 + 30) % (size.width + 120),
              (baseY + 120) % (size.height * 0.6) + 80 - jitter),
        ],
        starPaint,
      );
    }
  }

  void _drawAurora(Canvas canvas, Size size) {
    final palette = isRestWindow
        ? const [Color(0xFF2DD4BF), Color(0xFF38BDF8), Color(0xFFA855F7)]
        : const [Color(0xFF2563EB), Color(0xFF22D3EE), Color(0xFFF472B6)];
    final double time = elapsedMs / 900.0;
    for (var i = 0; i < 3; i++) {
      final double phase = time + i * 0.65;
      final double centerX =
          size.width * (0.2 + i * 0.35) + math.sin(phase * 1.8) * 48;
      final Rect rect = Rect.fromCenter(
        center: Offset(centerX, size.height * 0.24 + math.sin(phase) * 18),
        width: size.width * 0.55,
        height: 160,
      );
      final auroraPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            palette[i % palette.length].withOpacity(0.0),
            palette[i % palette.length].withOpacity(isRestWindow ? 0.45 : 0.35),
            palette[(i + 1) % palette.length].withOpacity(0.0),
          ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45);
      canvas.save();
      canvas.translate(math.sin(phase) * 24, 0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(80)),
        auroraPaint,
      );
      canvas.restore();
    }
  }

  void _drawParallaxLayers(Canvas canvas, Size size) {
    final baseColor = isRestWindow ? const Color(0xFF0B3B33) : const Color(0xFF0B1120);
    _drawParallaxBand(
      canvas,
      size,
      baseHeight: size.height * 0.58,
      amplitude: 24,
      speed: scrollSpeed * 0.45 + 18,
      color: baseColor.withOpacity(0.65),
    );
    _drawParallaxBand(
      canvas,
      size,
      baseHeight: size.height * 0.66,
      amplitude: 32,
      speed: scrollSpeed * 0.6 + 26,
      color: baseColor.withOpacity(0.5),
    );
  }

  void _drawParallaxBand(
    Canvas canvas,
    Size size, {
    required double baseHeight,
    required double amplitude,
    required double speed,
    required Color color,
  }) {
    final double width = size.width;
    const double step = 140;
    final double time = elapsedMs / 1000.0;
    final double offset = -(time * speed) % step;
    final path = Path()
      ..moveTo(-step, size.height)
      ..lineTo(-step, baseHeight);
    for (double x = -step; x <= width + step; x += step) {
      final double controlX = x + step / 2;
      final double controlY =
          baseHeight - math.sin((x + time * speed * 5) * 0.015) * amplitude;
      final double nextX = x + step;
      final double nextY =
          baseHeight - math.sin((nextX + time * speed * 5) * 0.015) * amplitude;
      path.quadraticBezierTo(controlX, controlY, nextX, nextY);
    }
    path
      ..lineTo(width + step, size.height)
      ..close();
    final paint = Paint()..color = color;
    canvas.save();
    canvas.translate(offset, 0);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawGround(Canvas canvas, Size size) {
    const double groundTop = 400.0;
    final groundRect = Rect.fromLTWH(0, groundTop, size.width, size.height - groundTop);
    final groundGradient = isRestWindow
        ? const LinearGradient(
            colors: [Color(0xFF0F4E3B), Color(0xFF22C55E), Color(0xFFA7F3D0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF0F766E), Color(0xFF22D3EE)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );
    final paint = Paint()..shader = groundGradient.createShader(groundRect);
    canvas.drawRect(groundRect, paint);

    final highlightPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.14),
          Colors.white.withOpacity(0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(groundRect);
    canvas.drawRect(groundRect, highlightPaint);

    final double stripeSpacing = 80;
    final double offset =
        (elapsedMs * (scrollSpeed * 0.25 + 20) / 1000) % stripeSpacing;
    final stripePaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (double x = -stripeSpacing; x < size.width + stripeSpacing; x += stripeSpacing) {
      final double startX = x + offset;
      canvas.drawLine(
        Offset(startX, groundTop + 18),
        Offset(startX + 26, groundTop + 92),
        stripePaint,
      );
    }

    final horizonPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF38BDF8).withOpacity(0.35),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, groundTop - 12, size.width, 24));
    canvas.drawRect(Rect.fromLTWH(0, groundTop - 12, size.width, 24), horizonPaint);
  }

  void _drawPlayer(Canvas canvas) {
    final double time = elapsedMs / 1000.0;
    final bool airborne = playerPosition.dy < 379;
    final double phase = time * (airborne ? 8.0 : 6.0);
    final double bob = airborne ? -6 + math.sin(phase) * 2 : math.sin(phase) * 3;
    final Offset center = playerPosition.translate(0, bob);

    final auraPaint = Paint()
      ..color = skin.auraColor.withOpacity(0.32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, 34, auraPaint);

    final bodyRect = Rect.fromCenter(center: center.translate(0, -2), width: 36, height: 46);
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [skin.primaryColor, skin.secondaryColor],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(bodyRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(14)),
      bodyPaint,
    );

    final chestRect = Rect.fromCenter(center: center.translate(0, 6), width: 28, height: 22);
    final chestPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.3),
          Colors.white.withOpacity(0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(chestRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(chestRect, const Radius.circular(10)),
      chestPaint,
    );

    final headCenter = center.translate(0, -28);
    final headRect = Rect.fromCircle(center: headCenter, radius: 14);
    final headPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, skin.primaryColor.withOpacity(0.85)],
        center: Alignment.topCenter,
        radius: 0.9,
      ).createShader(headRect);
    canvas.drawOval(headRect, headPaint);

    final visorRect = Rect.fromLTWH(headCenter.dx - 10, headCenter.dy - 6, 20, 10);
    final visorPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          skin.secondaryColor.withOpacity(0.95),
          Colors.white.withOpacity(0.65),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(visorRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(visorRect, const Radius.circular(6)),
      visorPaint,
    );

    final eyePaint = Paint()..color = Colors.black87;
    final double eyeShift = math.sin(phase) * 1.5;
    canvas.drawCircle(headCenter.translate(-5 + eyeShift, -2), 2.4, eyePaint);
    canvas.drawCircle(headCenter.translate(5 + eyeShift, -2), 2.4, eyePaint);

    final double legSwing = airborne ? -0.3 : math.sin(phase) * 0.8;
    final double legOppSwing = airborne ? 0.45 : math.sin(phase + math.pi) * 0.8;
    _drawLimb(
      canvas,
      origin: center.translate(-8, 18),
      length: 28,
      angle: legSwing,
      thickness: 6,
      color: skin.secondaryColor.withOpacity(0.9),
    );
    _drawLimb(
      canvas,
      origin: center.translate(8, 18),
      length: 28,
      angle: legOppSwing,
      thickness: 6,
      color: skin.primaryColor.withOpacity(0.9),
    );

    final double armSwing = airborne ? -0.25 : math.sin(phase + math.pi / 2) * 0.6;
    final double armOppSwing = airborne ? 0.32 : math.sin(phase + math.pi / 2 + math.pi) * 0.6;
    _drawLimb(
      canvas,
      origin: center.translate(-13, -4),
      length: 24,
      angle: armSwing,
      thickness: 5,
      color: skin.secondaryColor.withOpacity(0.85),
      rounded: true,
    );
    _drawLimb(
      canvas,
      origin: center.translate(13, -4),
      length: 24,
      angle: armOppSwing,
      thickness: 5,
      color: skin.primaryColor.withOpacity(0.85),
      rounded: true,
    );

    final thrusterRect = Rect.fromLTWH(center.dx - 8, center.dy + 12, 16, 30);
    final thrusterPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          skin.trailColor.withOpacity(airborne ? 0.6 : 0.35),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(thrusterRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawRRect(
      RRect.fromRectAndRadius(thrusterRect, const Radius.circular(8)),
      thrusterPaint,
    );
  }

  void _drawLimb(
    Canvas canvas, {
    required Offset origin,
    required double length,
    required double angle,
    required double thickness,
    required Color color,
    bool rounded = false,
  }) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);
    final rect = Rect.fromLTWH(-thickness / 2, 0, thickness, length);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color,
          Color.lerp(color, Colors.black, 0.25)!,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(rounded ? thickness : thickness * 0.6),
      ),
      paint,
    );
    canvas.restore();
  }

  void _drawObstacles(Canvas canvas) {
    for (final obstacle in obstacles) {
      final rect = Rect.fromLTWH(obstacle.x, obstacle.y, obstacle.width, obstacle.height);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      final colors = colorBlindFriendly
          ? const [Color(0xFFEAB308), Color(0xFFB45309)]
          : const [Color(0xFFFB7185), Color(0xFFF43F5E)];
      final bodyPaint = Paint()
        ..shader = LinearGradient(
          colors: [colors.first, Color.lerp(colors.last, Colors.black, 0.2)!],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect);
      canvas.drawRRect(rrect, bodyPaint);

      final shinePaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(0.4),
            Colors.white.withOpacity(0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect.deflate(2));
      canvas.drawRRect(rrect.deflate(2), shinePaint);

      final spikes = Path()..moveTo(rect.left, rect.top);
      final int segments = math.max(1, (rect.width / 12).floor());
      final double step = rect.width / segments;
      for (int i = 0; i < segments; i++) {
        final double x = rect.left + i * step;
        spikes
          ..lineTo(x + step / 2, rect.top - 10)
          ..lineTo(x + step, rect.top);
      }
      spikes.close();
      final spikePaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(colorBlindFriendly ? 0.55 : 0.4),
            colors.first.withOpacity(0.55),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(rect.left, rect.top - 10, rect.width, 12));
      canvas.drawPath(spikes, spikePaint);

      final glowPaint = Paint()
        ..color = (colorBlindFriendly ? const Color(0xFFEAB308) : const Color(0xFFF43F5E))
            .withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 18);
      canvas.drawRRect(rrect.inflate(4), glowPaint);
    }
  }

  void _drawCoins(Canvas canvas) {
    final double time = elapsedMs / 1000.0;
    for (final coin in coins) {
      final coinRect = Rect.fromCircle(center: coin.position, radius: coin.radius);
      final basePaint = Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFEF08A), Color(0xFFFACC15), Color(0xFFCA8A04)],
          center: Alignment.topLeft,
        ).createShader(coinRect);
      canvas.drawCircle(coin.position, coin.radius, basePaint);

      final twinkle = 0.5 + 0.5 * math.sin((coin.position.dx + time * 120) * 0.05);
      _coinHaloPaint.color = Colors.white.withOpacity(0.25 + 0.35 * twinkle);
      canvas.drawCircle(coin.position, coin.radius + 3, _coinHaloPaint);

      _coinSparklePaint.color = Colors.white.withOpacity(0.6 + 0.3 * twinkle);
      final double angle = time * 6 + coin.position.dx * 0.05;
      final Offset dir = Offset(math.cos(angle), math.sin(angle));
      final Offset ortho = Offset(-dir.dy, dir.dx);
      canvas.drawLine(coin.position - dir * 4, coin.position + dir * 4, _coinSparklePaint);
      canvas.drawLine(coin.position - ortho * 3, coin.position + ortho * 3, _coinSparklePaint);
    }
  }

  void _drawLines(Canvas canvas) {
    if (lines.isEmpty) {
      return;
    }

    final now = DateTime.now();
    for (final line in lines) {
      if (line.points.length < 2) {
        continue;
      }
      final path = Path()..moveTo(line.points.first.dx, line.points.first.dy);
      for (var i = 1; i < line.points.length; i++) {
        path.lineTo(line.points[i].dx, line.points[i].dy);
      }

      final age = now.difference(line.creationTime);
      final t = (1 - age.inMilliseconds / LineProvider.lineLifetime.inMilliseconds)
          .clamp(0.0, 1.0);
      _lineStrokePaint
        ..color = skin.trailColor.withOpacity(t)
        ..style = PaintingStyle.stroke;

      canvas.drawPath(path, _lineStrokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return frameId != oldDelegate.frameId ||
        lineSignature != oldDelegate.lineSignature ||
        isRestWindow != oldDelegate.isRestWindow ||
        colorBlindFriendly != oldDelegate.colorBlindFriendly ||
        skin.id != oldDelegate.skin.id ||
        obstacles.length != oldDelegate.obstacles.length ||
        coins.length != oldDelegate.coins.length ||
        playerPosition != oldDelegate.playerPosition;
  }
}
