import 'dart:math' as math;
import 'dart:ui';

enum ObstacleBehavior { groundBlock, movingHazard, hoveringShard, ceiling }

class DrawnLine {
  DrawnLine({required this.points, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();

  final List<Offset> points;
  final DateTime createdAt;
}

class Obstacle {
  Obstacle({
    required this.rect,
    this.behavior = ObstacleBehavior.groundBlock,
    Offset? anchor,
    this.amplitude = 0,
    this.frequency = 0,
    this.phase = 0,
  }) : anchor = anchor ?? rect.topLeft,
       _elapsed = 0;

  Rect rect;
  final ObstacleBehavior behavior;
  Offset anchor;
  final double amplitude;
  final double frequency;
  final double phase;
  double _elapsed;

  bool get isCeiling => behavior == ObstacleBehavior.ceiling;

  void translate(double dx) {
    rect = rect.shift(Offset(dx, 0));
    anchor = anchor.translate(dx, 0);
  }

  void update(double dt) {
    _elapsed += dt;
    switch (behavior) {
      case ObstacleBehavior.movingHazard:
      case ObstacleBehavior.hoveringShard:
        if (frequency <= 0 || amplitude <= 0) {
          return;
        }
        final double oscillation =
            math.sin((_elapsed * frequency * math.pi * 2) + phase) * amplitude;
        rect = Rect.fromLTWH(
          rect.left,
          anchor.dy + oscillation,
          rect.width,
          rect.height,
        );
        break;
      case ObstacleBehavior.groundBlock:
      case ObstacleBehavior.ceiling:
        break;
    }
  }
}

class Coin {
  Coin({required this.position, this.radius = 12});

  Offset position;
  final double radius;

  void translate(double dx) {
    position += Offset(dx, 0);
  }
}
