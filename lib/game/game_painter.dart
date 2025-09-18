import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'models.dart';

class GamePainter extends CustomPainter {
  GamePainter({
    required this.playerPosition,
    required this.playerRadius,
    required this.lines,
    required this.obstacles,
    required this.coins,
    required this.landingDust,
    required this.inkLevel,
    required this.groundY,
    required this.elapsed,
  });

  final Offset playerPosition;
  final double playerRadius;
  final List<DrawnLine> lines;
  final List<Obstacle> obstacles;
  final List<Coin> coins;
  final List<LandingDust> landingDust;
  final double inkLevel;
  final double groundY;
  final double elapsed;

  static final Paint _backgroundPaint = Paint();
  static final Paint _groundPaint = Paint();
  static final Paint _obstaclePaint = Paint()..color = const Color(0xFFef4444);
  static final Paint _obstacleShadowPaint =
      Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  static final Paint _coinPaint = Paint()..color = const Color(0xFFFACC15);
  static final Paint _coinHaloPaint =
      Paint()
        ..color = const Color(0xFFFDE68A).withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
  static final Paint _linePaint =
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 8
        ..shader = const LinearGradient(
          colors: [Color(0xFF38BDF8), Color(0xFF8B5CF6)],
        ).createShader(Rect.fromLTWH(0, 0, 200, 0));
  static final Paint _lineGlowPaint =
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 14
        ..color = const Color(0xFF38BDF8).withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
  static final Paint _playerPaint = Paint()..color = const Color(0xFF22D3EE);
  static final Paint _playerGlowPaint =
      Paint()
        ..color = const Color(0xFF22D3EE).withOpacity(0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
  static final LinearGradient _movingObstacleGradient = const LinearGradient(
    colors: [Color(0xFFF97316), Color(0xFFEF4444)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static final LinearGradient _hoverObstacleGradient = const LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF6366F1)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static final LinearGradient _hopperGradient = const LinearGradient(
    colors: [Color(0xFFFB923C), Color(0xFFF97316)],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
  );
  static final LinearGradient _spitterGradient = const LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
  );
  static final LinearGradient _projectileGradient = const LinearGradient(
    colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
  );
  static final Paint _projectileGlowPaint =
      Paint()
        ..color = const Color(0xFF38BDF8).withOpacity(0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
  static final Paint _ceilingPaint =
      Paint()..color = const Color(0xFF1E40AF).withOpacity(0.85);
  static final Paint _dustRingPaint =
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawGround(canvas, size);
    _drawLines(canvas);
    _drawObstacles(canvas);
    _drawCoins(canvas);
    _drawLandingDust(canvas);
    _drawPlayer(canvas);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final LinearGradient gradient = const LinearGradient(
      colors: [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF1E3A8A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    _backgroundPaint.shader = gradient.createShader(rect);
    canvas.drawRect(rect, _backgroundPaint);

    // simple starfield
    final Paint starPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.12)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2;
    final int starCount = (size.width / 28).round();
    for (var i = 0; i < starCount; i++) {
      final double x = (i * 37 + elapsed * 35) % (size.width + 40) - 20;
      final double y = (math.sin((elapsed * 0.6) + i) + 1) * size.height * 0.25;
      canvas.drawPoints(PointMode.points, [Offset(x, y + 40)], starPaint);
    }
  }

  void _drawGround(Canvas canvas, Size size) {
    final Rect groundRect = Rect.fromLTWH(
      0,
      groundY + playerRadius,
      size.width,
      size.height - (groundY + playerRadius),
    );
    final LinearGradient gradient = const LinearGradient(
      colors: [Color(0xFF0F172A), Color(0xFF0E7490), Color(0xFF22D3EE)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    _groundPaint.shader = gradient.createShader(groundRect);
    canvas.drawRect(groundRect, _groundPaint);
  }

  void _drawLines(Canvas canvas) {
    for (final DrawnLine line in lines) {
      final path = Path()..moveTo(line.points.first.dx, line.points.first.dy);
      for (var i = 1; i < line.points.length; i++) {
        path.lineTo(line.points[i].dx, line.points[i].dy);
      }
      canvas.drawPath(path, _lineGlowPaint);
      canvas.drawPath(path, _linePaint);
    }
  }

  void _drawObstacles(Canvas canvas) {
    for (final Obstacle obstacle in obstacles) {
      if (obstacle.behavior == ObstacleBehavior.spitProjectile) {
        _drawSpitProjectile(canvas, obstacle);
        continue;
      }
      final RRect rrect = RRect.fromRectAndRadius(
        obstacle.rect,
        obstacle.behavior == ObstacleBehavior.ceiling
            ? const Radius.circular(4)
            : const Radius.circular(12),
      );
      final Paint bodyPaint = _paintForObstacle(obstacle);
      if (!obstacle.isCeiling) {
        canvas.drawRRect(rrect.shift(const Offset(4, 6)), _obstacleShadowPaint);
      }
      canvas.drawRRect(rrect, bodyPaint);
      if (obstacle.behavior == ObstacleBehavior.hoveringShard) {
        final Paint aura =
            Paint()
              ..color = const Color(0xFF38BDF8).withOpacity(0.22)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
        canvas.drawRRect(rrect.inflate(6), aura);
      } else if (obstacle.behavior == ObstacleBehavior.floater) {
        final Paint aura =
            Paint()
              ..color = const Color(0xFF818CF8).withOpacity(0.18)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
        canvas.drawRRect(rrect.inflate(8), aura);
      } else if (obstacle.behavior == ObstacleBehavior.spitter) {
        final Paint glow =
            Paint()
              ..color = const Color(0xFFA855F7).withOpacity(0.2)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
        canvas.drawRRect(rrect.inflate(5), glow);
      }
    }
  }

  Paint _paintForObstacle(Obstacle obstacle) {
    switch (obstacle.behavior) {
      case ObstacleBehavior.movingHazard:
        return Paint()
          ..shader = _movingObstacleGradient.createShader(obstacle.rect);
      case ObstacleBehavior.hoveringShard:
      case ObstacleBehavior.floater:
        return Paint()
          ..shader = _hoverObstacleGradient.createShader(obstacle.rect);
      case ObstacleBehavior.ceiling:
        return _ceilingPaint;
      case ObstacleBehavior.hopper:
        return Paint()
          ..shader = _hopperGradient.createShader(obstacle.rect);
      case ObstacleBehavior.spitter:
        return Paint()
          ..shader = _spitterGradient.createShader(obstacle.rect);
      case ObstacleBehavior.spitProjectile:
        return Paint()
          ..shader = _projectileGradient.createShader(obstacle.rect);
      case ObstacleBehavior.groundBlock:
      default:
        return _obstaclePaint;
    }
  }

  void _drawSpitProjectile(Canvas canvas, Obstacle obstacle) {
    final RRect body =
        RRect.fromRectAndRadius(obstacle.rect, const Radius.circular(10));
    canvas.drawRRect(body.inflate(6), _projectileGlowPaint);
    final Paint projectilePaint = Paint()
      ..shader = _projectileGradient.createShader(obstacle.rect);
    canvas.drawRRect(body, projectilePaint);
  }

  void _drawCoins(Canvas canvas) {
    for (final Coin coin in coins) {
      final Rect rect = Rect.fromCircle(
        center: coin.position,
        radius: coin.radius + 6,
      );
      final LinearGradient gradient = const LinearGradient(
        colors: [Color(0xFFFFF7AE), Color(0xFFFACC15)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
      _coinPaint.shader = gradient.createShader(rect);
      canvas.drawCircle(coin.position, coin.radius, _coinPaint);
      canvas.drawCircle(coin.position, coin.radius + 4, _coinHaloPaint);
    }
  }

  void _drawLandingDust(Canvas canvas) {
    if (landingDust.isEmpty) {
      return;
    }
    for (final LandingDust dust in landingDust) {
      final double progress = dust.progress;
      final double fade = 1 - progress;
      final double intensity = dust.intensity.clamp(0.2, 1.4);
      final double spread =
          lerpDouble(14, 44 * intensity, progress) ?? (44 * intensity);
      final double height =
          lerpDouble(18 * intensity, 6, progress) ?? (18 * intensity);
      final Offset base = dust.position;

      final Paint puffPaint = Paint()
        ..color = Colors.white.withOpacity(0.18 + 0.32 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      final Paint groundGlow = Paint()
        ..color = const Color(0xFF38BDF8).withOpacity(0.18 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

      final Rect leftRect = Rect.fromCenter(
        center: Offset(base.dx - spread, base.dy - height * 0.38),
        width: (lerpDouble(24, 40, progress) ?? 32) * intensity.clamp(0.8, 1.2),
        height: height,
      );
      final Rect rightRect = Rect.fromCenter(
        center: Offset(base.dx + spread, base.dy - height * 0.38),
        width: (lerpDouble(24, 40, progress) ?? 32) * intensity.clamp(0.8, 1.2),
        height: height,
      );
      canvas.drawOval(leftRect, puffPaint);
      canvas.drawOval(rightRect, puffPaint);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(base.dx, base.dy + lerpDouble(2, 10, progress)!),
          width: lerpDouble(18, 46, progress)!,
          height: lerpDouble(6, 2, progress)!,
        ),
        groundGlow,
      );

      canvas.drawCircle(
        Offset(base.dx, base.dy - height * 0.2),
        lerpDouble(6 * intensity, 2, progress)!,
        Paint()..color = Colors.white.withOpacity(0.24 * fade),
      );

      final double ringRadius = lerpDouble(0, 38 * intensity, progress)!;
      if (ringRadius > 0) {
        _dustRingPaint.color = const Color(0xFF38BDF8).withOpacity(0.28 * fade);
        canvas.drawCircle(base, ringRadius, _dustRingPaint);
      }
    }
  }

  void _drawPlayer(Canvas canvas) {
    final double gaugeRadius = playerRadius + 14;
    final Paint gaugeBackground =
        Paint()
          ..color = Colors.white.withOpacity(0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;
    canvas.drawCircle(playerPosition, gaugeRadius, gaugeBackground);

    final Paint gaugePaint =
        Paint()
          ..color = const Color(0xFF38BDF8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
    final double sweep = 2 * math.pi * inkLevel.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: playerPosition, radius: gaugeRadius),
      -math.pi / 2,
      sweep,
      false,
      gaugePaint,
    );

    canvas.drawCircle(playerPosition, playerRadius * 1.6, _playerGlowPaint);
    canvas.drawCircle(playerPosition, playerRadius, _playerPaint);

    final Offset eyeOffset = Offset(playerRadius * 0.35, -playerRadius * 0.2);
    canvas.drawCircle(
      playerPosition + eyeOffset,
      playerRadius * 0.18,
      Paint()..color = Colors.white.withOpacity(0.8),
    );
    canvas.drawCircle(
      playerPosition + eyeOffset + const Offset(2, 0),
      playerRadius * 0.08,
      Paint()..color = Colors.black.withOpacity(0.8),
    );
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) {
    return true;
  }
}
