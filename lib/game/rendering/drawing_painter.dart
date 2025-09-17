import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/game_constants.dart';
import '../components/player_skin.dart';
import '../state/coin_manager.dart';
import '../state/line_manager.dart';
import '../state/obstacle_manager.dart';
import 'render_optimizer.dart';

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

  static final _DrawingResourceCache _resourceCache = _DrawingResourceCache();
  static final RenderOptimizer _renderOptimizer = RenderOptimizer();

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
    try {
      // レンダリング最適化の設定
      _renderOptimizer.setScreenBounds(size);
      _renderOptimizer.beginBatching();
      
      final resources = _resourceCache.resourcesFor(size);
      _drawBackground(canvas, size, resources);
      _drawGround(canvas, resources);
      _drawCoins(canvas);
      _drawObstacles(canvas);
      _drawLines(canvas);
      _drawPlayer(canvas);
      
      // バッチング済み描画の実行
      _renderOptimizer.executeBatch(canvas);
      
    } catch (error, stackTrace) {
      debugPrint('DrawingPainter paint error: $error');
      debugPrintStack(stackTrace: stackTrace);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.black,
      );
    }
  }

  void _drawBackground(
    Canvas canvas,
    Size size,
    _SizeResources resources,
  ) {
    final paint = resources.backgroundPaintFor(isRestWindow);
    canvas.drawRect(resources.backgroundRect, paint);

    _drawAurora(canvas, size, resources);
    _drawStarfield(canvas, resources);
    _drawParallaxLayers(canvas, size, resources);
  }

  void _drawStarfield(Canvas canvas, _SizeResources resources) {
    final double time = elapsedMs / 1000.0;
    final starPaint = resources.starPaint
      ..color = Colors.white.withOpacity(0.12 + 0.08 * math.sin(time * 2.2));
    final widthWrap = resources.size.width + 120;
    final heightBand = resources.size.height * 0.6;

    for (final baseX in resources.starBaseXs) {
      final double baseY = (baseX * 0.35 + time * 40) % heightBand;
      final double jitter = math.sin((baseX + time * 60) * 0.02) * 10;
      canvas.drawPoints(
        ui.PointMode.points,
        [
          Offset((baseX + time * 50) % widthWrap, baseY + 40 + jitter),
          Offset(
            (baseX * 0.8 + 30) % widthWrap,
            (baseY + 120) % heightBand + 80 - jitter,
          ),
        ],
        starPaint,
      );
    }
  }

  void _drawAurora(
    Canvas canvas,
    Size size,
    _SizeResources resources,
  ) {
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
      final auroraPaint = resources.auroraPaints[i]
        ..shader = LinearGradient(
          colors: [
            palette[i % palette.length].withOpacity(0.0),
            palette[i % palette.length].withOpacity(isRestWindow ? 0.45 : 0.35),
            palette[(i + 1) % palette.length].withOpacity(0.0),
          ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ).createShader(rect);
      canvas.save();
      canvas.translate(math.sin(phase) * 24, 0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(80)),
        auroraPaint,
      );
      canvas.restore();
    }
  }

  void _drawParallaxLayers(
    Canvas canvas,
    Size size,
    _SizeResources resources,
  ) {
    final baseColor = isRestWindow ? const Color(0xFF0B3B33) : const Color(0xFF0B1120);
    final firstPaint = resources.parallaxPaints[0]
      ..color = baseColor.withOpacity(0.65);
    final secondPaint = resources.parallaxPaints[1]
      ..color = baseColor.withOpacity(0.5);
    _drawParallaxBand(
      canvas,
      resources,
      bandIndex: 0,
      baseHeight: size.height * 0.58,
      amplitude: 24,
      speed: scrollSpeed * 0.45 + 18,
      paint: firstPaint,
    );
    _drawParallaxBand(
      canvas,
      resources,
      bandIndex: 1,
      baseHeight: size.height * 0.66,
      amplitude: 32,
      speed: scrollSpeed * 0.6 + 26,
      paint: secondPaint,
    );
  }

  void _drawParallaxBand(
    Canvas canvas,
    _SizeResources resources, {
    required int bandIndex,
    required double baseHeight,
    required double amplitude,
    required double speed,
    required Paint paint,
  }) {
    const double step = _SizeResources.parallaxStep;
    final double time = elapsedMs / 1000.0;
    final double offset = -(time * speed) % step;
    final path = resources.parallaxPaths[bandIndex]
      ..reset()
      ..moveTo(-step, resources.size.height)
      ..lineTo(-step, baseHeight);
    for (final x in resources.parallaxBaseXs) {
      final double controlX = x + step / 2;
      final double controlY =
          baseHeight - math.sin((x + time * speed * 5) * 0.015) * amplitude;
      final double nextX = x + step;
      final double nextY =
          baseHeight - math.sin((nextX + time * speed * 5) * 0.015) * amplitude;
      path.quadraticBezierTo(controlX, controlY, nextX, nextY);
    }
    path
      ..lineTo(resources.size.width + step, resources.size.height)
      ..close();
    canvas.save();
    canvas.translate(offset, 0);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawGround(Canvas canvas, _SizeResources resources) {
    final groundPaint = resources.groundPaintFor(isRestWindow);
    canvas.drawRect(resources.groundRect, groundPaint);

    canvas.drawRect(resources.groundRect, resources.highlightPaint);

    final double offset =
        (elapsedMs * (scrollSpeed * 0.25 + 20) / 1000) % _SizeResources.stripeSpacing;
    final stripePaint = resources.stripePaint;
    for (final baseX in resources.stripeBaseXs) {
      final double startX = baseX + offset;
      canvas.drawLine(
        Offset(startX, resources.groundRect.top + 18),
        Offset(startX + 26, resources.groundRect.top + 92),
        stripePaint,
      );
    }

    canvas.drawRect(resources.horizonRect, resources.horizonPaint);
  }

  void _drawPlayer(Canvas canvas) {
    final double time = elapsedMs / 1000.0;
    final bool airborne =
        playerPosition.dy < GameConstants.playerStartY - 1;
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
      
      // 視錐台カリングチェック
      if (!_renderOptimizer.isInFrustum(rect)) continue;
      
      // LOD計算
      final quality = _renderOptimizer.getLevelOfDetail(
        Offset(obstacle.x + obstacle.width / 2, obstacle.y + obstacle.height / 2),
        playerPosition,
      );
      
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      final colors = colorBlindFriendly
          ? const [Color(0xFFEAB308), Color(0xFFB45309)]
          : const [Color(0xFFFB7185), Color(0xFFF43F5E)];
      
      final bodyPaint = _renderOptimizer.getPaint()
        ..shader = LinearGradient(
          colors: [colors.first, Color.lerp(colors.last, Colors.black, 0.2)!],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect);
      canvas.drawRRect(rrect, bodyPaint);

      // 高品質時のみ詳細描画
      if (quality == RenderQuality.high) {
        final shinePaint = _renderOptimizer.getPaint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withOpacity(0.4),
              Colors.white.withOpacity(0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(rect.deflate(2));
        canvas.drawRRect(rrect.deflate(2), shinePaint);

        final spikes = _renderOptimizer.getPath()..moveTo(rect.left, rect.top);
        final int segments = math.max(1, (rect.width / 12).floor());
        final double step = rect.width / segments;
        for (int i = 0; i < segments; i++) {
          final double x = rect.left + i * step;
          spikes
            ..lineTo(x + step / 2, rect.top - 10)
            ..lineTo(x + step, rect.top);
        }
        spikes.close();
        
        final spikePaint = _renderOptimizer.getPaint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withOpacity(colorBlindFriendly ? 0.55 : 0.4),
              colors.first.withOpacity(0.55),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(rect.left, rect.top - 10, rect.width, 12));
        
        _renderOptimizer.drawOptimizedPath(canvas, spikes, spikePaint, quality: quality);

        final glowPaint = _renderOptimizer.getPaint()
          ..color = (colorBlindFriendly ? const Color(0xFFEAB308) : const Color(0xFFF43F5E))
              .withOpacity(0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 18);
        canvas.drawRRect(rrect.inflate(4), glowPaint);
        
        _renderOptimizer.returnPaint(shinePaint);
        _renderOptimizer.returnPath(spikes);
        _renderOptimizer.returnPaint(spikePaint);
        _renderOptimizer.returnPaint(glowPaint);
      }
      
      _renderOptimizer.returnPaint(bodyPaint);
    }
  }

  void _drawCoins(Canvas canvas) {
    final double time = elapsedMs / 1000.0;
    for (final coin in coins) {
      // LOD計算
      final quality = _renderOptimizer.getLevelOfDetail(
        coin.position,
        playerPosition,
      );
      
      final coinRect = Rect.fromCircle(center: coin.position, radius: coin.radius);
      
      // 視錐台カリングチェック
      if (!_renderOptimizer.isInFrustum(coinRect)) continue;
      
      final basePaint = _renderOptimizer.getPaint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFEF08A), Color(0xFFFACC15), Color(0xFFCA8A04)],
          center: Alignment.topLeft,
        ).createShader(coinRect);
      
      // 最適化された円描画
      _renderOptimizer.drawOptimizedCircle(
        canvas,
        coin.position,
        coin.radius,
        basePaint,
        quality: quality,
      );

      // 高品質時のみエフェクト描画
      if (quality == RenderQuality.high) {
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
      
      _renderOptimizer.returnPaint(basePaint);
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

class _DrawingResourceCache {
  final Map<Size, _SizeResources> _cache = <Size, _SizeResources>{};

  _SizeResources resourcesFor(Size size) {
    return _cache.putIfAbsent(size, () => _SizeResources(size));
  }
}

class _SizeResources {
  _SizeResources(this.size)
      : backgroundRect = Rect.fromLTWH(0, 0, size.width, size.height),
        groundRect = Rect.fromLTWH(
          0,
          _groundTop,
          size.width,
          math.max(0, size.height - _groundTop),
        ),
        horizonRect = Rect.fromLTWH(0, _groundTop - 12, size.width, 24),
        backgroundPaint = Paint(),
        restBackgroundPaint = Paint(),
        groundPaint = Paint(),
        restGroundPaint = Paint(),
        highlightPaint = Paint(),
        horizonPaint = Paint(),
        stripePaint = Paint()
          ..color = Colors.white.withOpacity(0.08)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
        starPaint = Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2,
        auroraPaints = List.generate(
          3,
          (_) => Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45),
        ),
        parallaxPaints = [Paint(), Paint()],
        parallaxPaths = [Path(), Path()],
        starBaseXs = _generateStarBaseXs(size.width),
        parallaxBaseXs = _generateParallaxBaseXs(size.width),
        stripeBaseXs = _generateStripeBaseXs(size.width) {
    highlightPaint.shader = LinearGradient(
      colors: [
        Colors.white.withOpacity(0.14),
        Colors.white.withOpacity(0.0),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(groundRect);

    horizonPaint.shader = LinearGradient(
      colors: [
        const Color(0xFF38BDF8).withOpacity(0.35),
        Colors.transparent,
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(horizonRect);
  }

  static const double _groundTop = 400.0;
  static const double stripeSpacing = 80;
  static const double parallaxStep = 140;

  final Size size;
  final Rect backgroundRect;
  final Rect groundRect;
  final Rect horizonRect;
  final Paint backgroundPaint;
  final Paint restBackgroundPaint;
  final Paint groundPaint;
  final Paint restGroundPaint;
  final Paint highlightPaint;
  final Paint horizonPaint;
  final Paint stripePaint;
  final Paint starPaint;
  final List<Paint> auroraPaints;
  final List<Paint> parallaxPaints;
  final List<Path> parallaxPaths;
  final List<double> starBaseXs;
  final List<double> parallaxBaseXs;
  final List<double> stripeBaseXs;

  Paint backgroundPaintFor(bool restWindow) {
    final gradient =
        restWindow ? _restBackgroundGradient : _defaultBackgroundGradient;
    final paint = restWindow ? restBackgroundPaint : backgroundPaint;
    paint.shader = gradient.createShader(backgroundRect);
    return paint;
  }

  Paint groundPaintFor(bool restWindow) {
    final gradient =
        restWindow ? _restGroundGradient : _defaultGroundGradient;
    final paint = restWindow ? restGroundPaint : groundPaint;
    paint.shader = gradient.createShader(groundRect);
    return paint;
  }

  static const LinearGradient _defaultBackgroundGradient = LinearGradient(
    colors: [Color(0xFF020617), Color(0xFF0B1220), Color(0xFF1D4ED8)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient _restBackgroundGradient = LinearGradient(
    colors: [Color(0xFF02131E), Color(0xFF0F2A4E), Color(0xFF34D399)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient _defaultGroundGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF0F766E), Color(0xFF22D3EE)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient _restGroundGradient = LinearGradient(
    colors: [Color(0xFF0F4E3B), Color(0xFF22C55E), Color(0xFFA7F3D0)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

List<double> _generateStarBaseXs(double width) {
  final values = <double>[];
  for (double x = 0; x < width + 140; x += 70) {
    values.add(x);
  }
  return values;
}

List<double> _generateParallaxBaseXs(double width) {
  final values = <double>[];
  for (double x = -_SizeResources.parallaxStep;
      x <= width + _SizeResources.parallaxStep;
      x += _SizeResources.parallaxStep) {
    values.add(x);
  }
  return values;
}

List<double> _generateStripeBaseXs(double width) {
  final values = <double>[];
  for (double x = -_SizeResources.stripeSpacing;
      x < width + _SizeResources.stripeSpacing;
      x += _SizeResources.stripeSpacing) {
    values.add(x);
  }
  return values;
}
