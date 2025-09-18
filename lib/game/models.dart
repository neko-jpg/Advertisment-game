import 'dart:math' as math;
import 'dart:ui';

enum ObstacleBehavior {
  groundBlock,
  movingHazard,
  hoveringShard,
  ceiling,
  hopper,
  floater,
  spitter,
  spitProjectile,
}

class HopperConfig {
  HopperConfig({
    required this.restTop,
    required this.jumpVelocity,
    required this.gravity,
    required this.hopInterval,
    required this.triggerDistance,
  });

  final double restTop;
  final double jumpVelocity;
  final double gravity;
  final double hopInterval;
  final double triggerDistance;

  double timeSinceHop = 0;
  double verticalVelocity = 0;
  bool hopping = false;
}

class SpitterConfig {
  SpitterConfig({
    required this.fireInterval,
    required this.triggerDistance,
    required this.projectileSpeed,
    required this.projectileLifetime,
    required this.projectileSize,
    this.initialDelay = 0,
  }) : cooldown = initialDelay;

  final double fireInterval;
  final double triggerDistance;
  final double projectileSpeed;
  final double projectileLifetime;
  final Size projectileSize;
  final double initialDelay;

  double cooldown;
}

class ProjectileConfig {
  ProjectileConfig({
    required this.velocity,
    required this.lifetime,
  });

  final Offset velocity;
  final double lifetime;

  double elapsed = 0;
}

class DrawnLine {
  DrawnLine({required this.points, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();

  final List<Offset> points;
  final DateTime createdAt;
}

class LandingDust {
  LandingDust({
    required this.position,
    required this.intensity,
    this.lifetime = 0.6,
  })  : assert(intensity > 0),
        elapsed = 0;

  final Offset position;
  final double intensity;
  final double lifetime;
  double elapsed;

  double get progress => (elapsed / lifetime).clamp(0.0, 1.0);

  bool get isFinished => elapsed >= lifetime;

  void update(double dt) {
    elapsed += dt;
  }
}

class Obstacle {
  Obstacle({
    required this.rect,
    this.behavior = ObstacleBehavior.groundBlock,
    Offset? anchor,
    this.amplitude = 0,
    this.frequency = 0,
    this.phase = 0,
    this.hopperConfig,
    this.spitterConfig,
    this.projectileConfig,
  }) : anchor = anchor ?? rect.topLeft,
       _elapsed = 0;

  Rect rect;
  final ObstacleBehavior behavior;
  Offset anchor;
  final double amplitude;
  final double frequency;
  final double phase;
  double _elapsed;
  final HopperConfig? hopperConfig;
  final SpitterConfig? spitterConfig;
  final ProjectileConfig? projectileConfig;
  bool _expired = false;

  bool get isCeiling => behavior == ObstacleBehavior.ceiling;
  bool get isExpired => _expired;

  void translate(double dx) {
    rect = rect.shift(Offset(dx, 0));
    anchor = anchor.translate(dx, 0);
  }

  void expire() {
    _expired = true;
  }

  List<Obstacle> update(double dt, {Offset? playerPosition}) {
    final List<Obstacle> spawned = [];
    _elapsed += dt;
    switch (behavior) {
      case ObstacleBehavior.movingHazard:
      case ObstacleBehavior.hoveringShard:
      case ObstacleBehavior.floater:
        if (frequency > 0 && amplitude > 0) {
          final double oscillation =
              math.sin((_elapsed * frequency * math.pi * 2) + phase) * amplitude;
          rect = Rect.fromLTWH(
            rect.left,
            anchor.dy + oscillation,
            rect.width,
            rect.height,
          );
        }
        break;
      case ObstacleBehavior.groundBlock:
      case ObstacleBehavior.ceiling:
        break;
      case ObstacleBehavior.hopper:
        final HopperConfig? config = hopperConfig;
        if (config == null) {
          break;
        }
        config.timeSinceHop += dt;
        final bool inRange = playerPosition != null &&
            playerPosition.dx > rect.left - config.triggerDistance;
        if (!config.hopping && inRange && config.timeSinceHop >= config.hopInterval) {
          config.hopping = true;
          config.verticalVelocity = -config.jumpVelocity;
          config.timeSinceHop = 0;
        }
        if (config.hopping) {
          config.verticalVelocity += config.gravity * dt;
          final double nextTop = rect.top + config.verticalVelocity * dt;
          if (nextTop >= config.restTop) {
            rect = Rect.fromLTWH(rect.left, config.restTop, rect.width, rect.height);
            config.hopping = false;
            config.verticalVelocity = 0;
          } else {
            rect = Rect.fromLTWH(rect.left, nextTop, rect.width, rect.height);
          }
        }
        break;
      case ObstacleBehavior.spitter:
        final SpitterConfig? config = spitterConfig;
        if (config == null) {
          break;
        }
        config.cooldown -= dt;
        final bool playerAhead = playerPosition != null &&
            playerPosition.dx > rect.left - config.triggerDistance;
        if (config.cooldown <= 0 && playerAhead) {
          config.cooldown = config.fireInterval;
          final Rect projectileRect = Rect.fromLTWH(
            rect.right - config.projectileSize.width / 2,
            rect.top - config.projectileSize.height,
            config.projectileSize.width,
            config.projectileSize.height,
          );
          spawned.add(
            Obstacle(
              rect: projectileRect,
              behavior: ObstacleBehavior.spitProjectile,
              projectileConfig: ProjectileConfig(
                velocity: Offset(0, -config.projectileSpeed),
                lifetime: config.projectileLifetime,
              ),
            ),
          );
        }
        break;
      case ObstacleBehavior.spitProjectile:
        final ProjectileConfig? projectile = projectileConfig;
        if (projectile == null) {
          break;
        }
        rect = rect.shift(projectile.velocity * dt);
        projectile.elapsed += dt;
        if (projectile.elapsed >= projectile.lifetime) {
          expire();
        }
        break;
    }
    return spawned;
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
