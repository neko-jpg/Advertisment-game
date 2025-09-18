import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Flame を使ったゲーム版 main.dart。
///
/// 元コードでは CustomPainter と setState を使って手動でゲームループと描画を管理していたが、
/// FlameGame を継承することで update/render サイクル・当たり判定・入力処理をエンジンに委譲している。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(GameWidget(game: LineRunnerGame()));
}

/// Flame のゲームループに載せ替えたエンドレスランナー本体。
class LineRunnerGame extends FlameGame
    with HasCollisionDetection, PanDetector, TapDetector {
  LineRunnerGame();

  /// 旧コードでは setState でタイマー駆動していたが、Flame の update(dt) がその役目を担う。
  final double gravity = 900;
  final double scrollSpeed = 180;
  final double jumpVelocity = 460;
  final int maxDrawnLines = 10;

  final List<LinePlatform> _platforms = [];
  final Paint _previewPaint = Paint()
    ..color = Colors.orangeAccent
    ..strokeWidth = 8
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  PlayerComponent? _player;
  LinePlatform? _ground;
  Vector2? _dragStart;
  Vector2? _dragCurrent;
  double _backgroundScroll = 0;
  bool _initialized = false;

  double get playerAnchorX => size.x * 0.25;
  double get groundHeight => size.y * 0.18;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewport = FixedResolutionViewport(Vector2(480, 800));
  }

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    if (!_initialized && canvasSize.x > 0 && canvasSize.y > 0) {
      _initialized = true;
      _initializeWorld();
    }
  }

  void _initializeWorld() {
    final groundY = size.y - groundHeight;
    final playerStart = Vector2(playerAnchorX, groundY - 60);

    // カスタムペインター時代に相当する初期床を Flame のコンポーネントで構築。
    _ground = LinePlatform(
      start: Vector2(-size.x, groundY),
      end: Vector2(size.x * 2, groundY),
      thickness: 26,
      color: const Color(0xFF66BB6A),
      pinned: true,
    );
    add(_ground!);
    _platforms.add(_ground!);

    // プレイヤーもコンポーネント化し、Flame の衝突コールバックを活用。
    final player = PlayerComponent(
      gravity: gravity,
      jumpVelocity: jumpVelocity,
      size: Vector2(48, 48),
      position: playerStart,
    );
    add(player);
    _player = player;
  }

  @override
  void render(Canvas canvas) {
    // 背景描画も render(canvas) をオーバーライドして実施。
    _renderBackground(canvas);
    super.render(canvas);
    _renderPreviewLine(canvas);
  }

  void _renderBackground(Canvas canvas) {
    if (size.x == 0 || size.y == 0) {
      return;
    }

    final skyRect = Rect.fromLTWH(0, 0, size.x, size.y);
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF87CEEB), Color(0xFFE0F7FA)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    final hillHeight = size.y * 0.25;
    final patternWidth = size.x;
    final offset = _backgroundScroll % patternWidth;
    final hillPaint = Paint()..color = const Color(0xFF4FC3F7).withOpacity(0.45);

    for (double x = -offset - patternWidth; x < size.x + patternWidth; x += patternWidth) {
      final path = Path()
        ..moveTo(x, size.y)
        ..quadraticBezierTo(
          x + patternWidth / 2,
          size.y - hillHeight,
          x + patternWidth,
          size.y,
        )
        ..close();
      canvas.drawPath(path, hillPaint);
    }

    final groundTop = size.y - groundHeight;
    final groundRect = Rect.fromLTWH(0, groundTop, size.x, groundHeight);
    canvas.drawRect(groundRect, Paint()..color = const Color(0xFF2E7D32));

    final stripeWidth = 42.0;
    final stripeOffset = _backgroundScroll % stripeWidth;
    final stripePaint = Paint()..color = Colors.white.withOpacity(0.12);
    for (double x = -stripeOffset; x < size.x + stripeWidth; x += stripeWidth) {
      canvas.drawRect(
        Rect.fromLTWH(x, groundTop, stripeWidth / 2, groundHeight),
        stripePaint,
      );
    }
  }

  void _renderPreviewLine(Canvas canvas) {
    if (_dragStart == null || _dragCurrent == null) {
      return;
    }
    final start = _dragStart!;
    final current = _dragCurrent!;
    if (start == current) {
      return;
    }
    canvas.drawLine(Offset(start.x, start.y), Offset(current.x, current.y), _previewPaint);
  }

  @override
  void update(double dt) {
    if (!_initialized) {
      return;
    }

    // 背景スクロールを進める。旧コードでの setState 相当。
    _backgroundScroll += scrollSpeed * dt;

    // 線コンポーネントをまとめて左へ流し、エンドレスランナー風の見た目に。
    final double shift = scrollSpeed * dt;
    for (final platform in _platforms) {
      if (!platform.pinned) {
        platform.shiftHorizontally(shift);
      }
    }

    super.update(dt);

    final player = _player;
    if (player != null) {
      player.lockToAnchor(playerAnchorX);
      if (player.position.y > size.y + player.size.y * 2) {
        _resetPlayer();
      }
    }

    _removeExpiredPlatforms();
  }

  void _resetPlayer() {
    final player = _player;
    final ground = _ground;
    if (player == null || ground == null) {
      return;
    }
    final respawnSource = Vector2(playerAnchorX, ground.position.y);
    final respawnY = ground.surfacePointFor(respawnSource).y - player.size.y / 2;
    player
      ..position = Vector2(playerAnchorX, respawnY)
      ..resetMotion();
  }

  void _removeExpiredPlatforms() {
    _platforms
        .where((platform) => !platform.pinned && platform.endPoint.x < -size.x)
        .toList()
        .forEach((platform) {
      platform.removeFromParent();
      _platforms.remove(platform);
    });
  }

  @override
  void onTapDown(TapDownInfo info) {
    super.onTapDown(info);
    _player?.tryJump();
  }

  @override
  void onPanStart(DragStartInfo info) {
    super.onPanStart(info);
    _dragStart = info.eventPosition.game.clone();
    _dragCurrent = _dragStart;
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    super.onPanUpdate(info);
    _dragCurrent = info.eventPosition.game.clone();
  }

  @override
  void onPanEnd(DragEndInfo info) {
    super.onPanEnd(info);
    _commitDrawnLine();
  }

  @override
  void onPanCancel() {
    super.onPanCancel();
    _dragStart = null;
    _dragCurrent = null;
  }

  void _commitDrawnLine() {
    if (_dragStart == null || _dragCurrent == null) {
      return;
    }

    final start = _dragStart!;
    final end = _dragCurrent!;
    _dragStart = null;
    _dragCurrent = null;

    if ((start - end).length < 32) {
      return; // 短すぎる線は無視。
    }

    final line = LinePlatform(
      start: start,
      end: end,
      thickness: 18,
      color: Colors.lightBlueAccent,
    );
    add(line);
    _platforms.add(line);

    final nonPinned = _platforms.where((platform) => !platform.pinned).toList();
    while (nonPinned.length > maxDrawnLines) {
      final oldest = nonPinned.removeAt(0);
      oldest.removeFromParent();
      _platforms.remove(oldest);
    }
  }
}

/// プレイヤーキャラクター。
/// カスタムペインター版の矩形描画 + 手動物理を Flame の PositionComponent に移植。
class PlayerComponent extends PositionComponent with CollisionCallbacks, HasGameRef<LineRunnerGame> {
  PlayerComponent({
    required this.gravity,
    required this.jumpVelocity,
    required super.size,
    required super.position,
  }) : super(anchor: Anchor.center);

  final double gravity;
  final double jumpVelocity;

  final Vector2 velocity = Vector2.zero();
  bool _isGrounded = false;
  int _groundContacts = 0;

  final Paint _paint = Paint()..color = const Color(0xFFFF7043);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.active));
  }

  @override
  void update(double dt) {
    super.update(dt);

    velocity.y += gravity * dt;
    position += velocity * dt;

    if (!_isGrounded) {
      // 空中では軽く前傾させてスピード感を演出。
      angle = math.pi / 36;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.x,
      height: size.y,
    );
    canvas.drawRRect(RRect.fromRectXY(rect, 10, 10), _paint);
  }

  void lockToAnchor(double anchorX) {
    position.x = anchorX;
  }

  void resetMotion() {
    velocity.setValues(0, 0);
    _isGrounded = false;
    _groundContacts = 0;
    angle = 0;
  }

  void tryJump() {
    if (_isGrounded) {
      velocity.y = -jumpVelocity;
      _isGrounded = false;
      angle = -math.pi / 18;
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is! LinePlatform) {
      return;
    }

    _groundContacts += 1;
    _isGrounded = true;
    if (velocity.y > 0) {
      velocity.y = 0;
    }

    final anchorX = gameRef.playerAnchorX;
    final bottomCenter = Vector2(anchorX, position.y + size.y / 2);
    final surfacePoint = other.surfacePointFor(bottomCenter);
    position
      ..x = anchorX
      ..y = surfacePoint.y - size.y / 2;
    angle = other.surfaceAngle;
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is! LinePlatform) {
      return;
    }

    _groundContacts = math.max(0, _groundContacts - 1);
    if (_groundContacts == 0) {
      _isGrounded = false;
    }
  }
}

/// Flame の衝突システムを使った足場コンポーネント。
/// CustomPainter で引いていた線を PolygonHitbox で表現している。
class LinePlatform extends PositionComponent with CollisionCallbacks {
  LinePlatform({
    required Vector2 start,
    required Vector2 end,
    this.thickness = 16,
    this.color = Colors.lightBlueAccent,
    this.pinned = false,
  })  : _start = start.clone(),
        _end = end.clone(),
        super(anchor: Anchor.center) {
    _rebuildGeometry();
  }

  final double thickness;
  final Color color;
  final bool pinned;

  final Paint _paint = Paint();
  Vector2 _start;
  Vector2 _end;
  late Vector2 _direction;
  late Vector2 _normal;
  late double surfaceAngle;

  Vector2 get startPoint => _start;
  Vector2 get endPoint => _end;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(collisionType: CollisionType.passive));
  }

  void _rebuildGeometry() {
    Vector2 delta = _end - _start;
    double length = delta.length;
    if (length == 0) {
      // 退避: 長さ0の線は最低長に。
      delta = Vector2(1, 0);
      length = 1;
      _end = _start + delta;
    }
    _direction = delta.normalized();
    _normal = Vector2(-_direction.y, _direction.x);
    if (_normal.y > 0) {
      _normal = -_normal;
    }
    surfaceAngle = math.atan2(_direction.y, _direction.x);

    position = (_start + _end) / 2;
    size = Vector2(length.abs(), thickness);
    angle = surfaceAngle;

    _paint
      ..color = color
      ..style = PaintingStyle.fill;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.x,
      height: size.y,
    );
    canvas.drawRRect(RRect.fromRectXY(rect, 12, 12), _paint);
  }

  /// 背景スクロールに合わせて左方向へ移動させる。
  void shiftHorizontally(double distance) {
    position.x -= distance;
    _start.x -= distance;
    _end.x -= distance;
  }

  /// 指定座標にもっとも近い線分上の点を返す。
  Vector2 _nearestPoint(Vector2 point) {
    final segment = _end - _start;
    final lengthSquared = segment.length2;
    if (lengthSquared == 0) {
      return _start.clone();
    }
    final t = ((point - _start).dot(segment) / lengthSquared).clamp(0.0, 1.0);
    return _start + segment * t;
  }

  /// プレイヤーの接地位置（線の上面）を計算する。
  Vector2 surfacePointFor(Vector2 bottomCenter) {
    final nearest = _nearestPoint(bottomCenter);
    return nearest + _normal * (thickness / 2);
  }
}
