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
  });

  final Offset playerPosition;
  final List<DrawnLine> lines;
  final List<Obstacle> obstacles;
  final List<Coin> coins;
  final PlayerSkin skin;

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
    final backgroundPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF38BDF8)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    final starPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;

    for (var i = 0; i < size.width; i += 90) {
      final y = (i * 0.4) % (size.height * 0.5);
      canvas.drawPoints(
        ui.PointMode.points,
        [Offset(i + 20, y + 40), Offset(i + 60, (y + 120) % (size.height * 0.5) + 60)],
        starPaint,
      );
    }
  }

  void _drawGround(Canvas canvas, Size size) {
    const groundTop = 400.0;
    final groundRect = Rect.fromLTWH(0, groundTop, size.width, size.height - groundTop);
    final groundPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0F766E), Color(0xFF047857)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(groundRect);
    canvas.drawRect(groundRect, groundPaint);

    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, groundTop), Offset(x + 20, groundTop + 16), gridPaint);
    }
  }

  void _drawPlayer(Canvas canvas) {
    const double radius = 20;
    final playerRect = Rect.fromCircle(center: playerPosition, radius: radius);
    final playerPaint = Paint()
      ..shader = RadialGradient(
        colors: [skin.primaryColor, skin.secondaryColor],
        center: Alignment.topLeft,
        radius: 1.2,
      ).createShader(playerRect);
    canvas.drawCircle(playerPosition, radius, playerPaint);

    final auraPaint = Paint()
      ..color = skin.auraColor.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(playerPosition, radius + 12, auraPaint);
  }

  void _drawObstacles(Canvas canvas) {
    for (final obstacle in obstacles) {
      final rect = Rect.fromLTWH(obstacle.x, obstacle.y, obstacle.width, obstacle.height);
      final paint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFB7185), Color(0xFFF43F5E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(rrect, paint);

      final highlight = Paint()
        ..color = Colors.white.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(rrect.deflate(3), highlight);
    }
  }

  void _drawCoins(Canvas canvas) {
    for (final coin in coins) {
      final coinRect = Rect.fromCircle(center: coin.position, radius: coin.radius);
      final paint = Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFEF08A), Color(0xFFFACC15), Color(0xFFCA8A04)],
          center: Alignment.topLeft,
        ).createShader(coinRect);
      canvas.drawCircle(coin.position, coin.radius, paint);

      final sparkle = Paint()
        ..color = Colors.white.withOpacity(0.7)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        coin.position + const Offset(-4, -4),
        coin.position + const Offset(4, 4),
        sparkle,
      );
      canvas.drawLine(
        coin.position + const Offset(-4, 4),
        coin.position + const Offset(4, -4),
        sparkle,
      );
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
      final paint = Paint()
        ..color = skin.trailColor.withOpacity(t)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke;

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return true;
  }
}
