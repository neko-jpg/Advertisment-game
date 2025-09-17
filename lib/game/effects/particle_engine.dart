import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Base particle class with core properties and physics
abstract class Particle {
  Offset position;
  Offset velocity;
  Offset acceleration;
  Color color;
  double size;
  double opacity;
  int lifetime;
  int maxLifetime;
  bool isActive;

  Particle({
    required this.position,
    required this.velocity,
    this.acceleration = Offset.zero,
    required this.color,
    required this.size,
    this.opacity = 1.0,
    required this.lifetime,
    this.isActive = true,
  }) : maxLifetime = lifetime;

  /// Update particle physics and properties
  void update(double deltaTime) {
    if (!isActive) return;

    // Apply physics
    velocity = Offset(
      velocity.dx + acceleration.dx * deltaTime,
      velocity.dy + acceleration.dy * deltaTime,
    );
    
    position = Offset(
      position.dx + velocity.dx * deltaTime,
      position.dy + velocity.dy * deltaTime,
    );

    // Update lifetime
    lifetime--;
    if (lifetime <= 0) {
      isActive = false;
    }

    // Update opacity based on lifetime
    opacity = (lifetime / maxLifetime).clamp(0.0, 1.0);

    // Custom update logic
    updateCustom(deltaTime);
  }

  /// Custom update logic for specific particle types
  void updateCustom(double deltaTime) {}

  /// Render the particle
  void render(Canvas canvas, Paint paint);

  /// Check if particle should be removed
  bool shouldRemove() {
    return !isActive || lifetime <= 0;
  }
}

/// Object pool for efficient particle management
class ParticlePool<T extends Particle> {
  final List<T> _available = [];
  final List<T> _active = [];
  final T Function() _createParticle;
  final int maxSize;

  ParticlePool({
    required T Function() createParticle,
    this.maxSize = 1000,
  }) : _createParticle = createParticle;

  /// Get a particle from the pool
  T? acquire() {
    T particle;
    
    if (_available.isNotEmpty) {
      particle = _available.removeLast();
    } else if (_active.length < maxSize) {
      particle = _createParticle();
    } else {
      return null; // Pool is full
    }

    _active.add(particle);
    particle.isActive = true;
    return particle;
  }

  /// Return a particle to the pool
  void release(T particle) {
    if (_active.remove(particle)) {
      particle.isActive = false;
      _available.add(particle);
    }
  }

  /// Get all active particles
  List<T> get activeParticles => List.unmodifiable(_active);

  /// Update all active particles
  void updateAll(double deltaTime) {
    final toRemove = <T>[];
    
    for (final particle in _active) {
      particle.update(deltaTime);
      if (particle.shouldRemove()) {
        toRemove.add(particle);
      }
    }

    // Return inactive particles to pool
    for (final particle in toRemove) {
      release(particle);
    }
  }

  /// Render all active particles
  void renderAll(Canvas canvas, Paint paint) {
    for (final particle in _active) {
      if (particle.isActive) {
        particle.render(canvas, paint);
      }
    }
  }

  /// Clear all particles
  void clear() {
    _available.addAll(_active);
    _active.clear();
    for (final particle in _available) {
      particle.isActive = false;
    }
  }

  /// Get pool statistics
  ParticlePoolStats get stats => ParticlePoolStats(
    active: _active.length,
    available: _available.length,
    total: _active.length + _available.length,
    maxSize: maxSize,
  );
}

/// Statistics for particle pool monitoring
class ParticlePoolStats {
  final int active;
  final int available;
  final int total;
  final int maxSize;

  const ParticlePoolStats({
    required this.active,
    required this.available,
    required this.total,
    required this.maxSize,
  });

  double get utilization => total > 0 ? active / total : 0.0;
  bool get isNearCapacity => active > maxSize * 0.8;
}

/// Main particle system manager
class ParticleSystem {
  final Map<Type, ParticlePool> _pools = {};
  final List<ParticleEmitter> _emitters = [];
  bool _isEnabled = true;
  int _maxParticlesPerFrame = 100;

  /// Enable/disable the particle system
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      clearAll();
    }
  }

  bool get isEnabled => _isEnabled;

  /// Set maximum particles that can be spawned per frame
  void setMaxParticlesPerFrame(int max) {
    _maxParticlesPerFrame = max;
  }

  /// Register a particle pool
  void registerPool<T extends Particle>(ParticlePool<T> pool) {
    _pools[T] = pool;
  }

  /// Get a particle pool by type
  ParticlePool<T>? getPool<T extends Particle>() {
    return _pools[T] as ParticlePool<T>?;
  }

  /// Add an emitter to the system
  void addEmitter(ParticleEmitter emitter) {
    _emitters.add(emitter);
  }

  /// Remove an emitter from the system
  void removeEmitter(ParticleEmitter emitter) {
    _emitters.remove(emitter);
  }

  /// Update all particles and emitters
  void update(double deltaTime) {
    if (!_isEnabled) return;

    // Update all particle pools
    for (final pool in _pools.values) {
      pool.updateAll(deltaTime);
    }

    // Update all emitters
    for (final emitter in _emitters.toList()) {
      emitter.update(deltaTime);
      if (emitter.isFinished) {
        _emitters.remove(emitter);
      }
    }
  }

  /// Render all particles
  void render(Canvas canvas, Paint paint) {
    if (!_isEnabled) return;

    for (final pool in _pools.values) {
      pool.renderAll(canvas, paint);
    }
  }

  /// Clear all particles
  void clearAll() {
    for (final pool in _pools.values) {
      pool.clear();
    }
    _emitters.clear();
  }

  /// Get system statistics
  ParticleSystemStats get stats {
    int totalActive = 0;
    int totalAvailable = 0;
    final poolStats = <Type, ParticlePoolStats>{};

    for (final entry in _pools.entries) {
      final stats = entry.value.stats;
      poolStats[entry.key] = stats;
      totalActive += stats.active;
      totalAvailable += stats.available;
    }

    return ParticleSystemStats(
      totalActive: totalActive,
      totalAvailable: totalAvailable,
      emitterCount: _emitters.length,
      poolStats: poolStats,
    );
  }
}

/// System-wide statistics
class ParticleSystemStats {
  final int totalActive;
  final int totalAvailable;
  final int emitterCount;
  final Map<Type, ParticlePoolStats> poolStats;

  const ParticleSystemStats({
    required this.totalActive,
    required this.totalAvailable,
    required this.emitterCount,
    required this.poolStats,
  });

  int get totalParticles => totalActive + totalAvailable;
  double get systemUtilization => totalParticles > 0 ? totalActive / totalParticles : 0.0;
}

/// Base class for particle emitters
abstract class ParticleEmitter {
  Offset position;
  bool isActive;
  double duration;
  double elapsed;
  int particlesPerSecond;
  double _accumulator = 0.0;

  ParticleEmitter({
    required this.position,
    this.isActive = true,
    this.duration = -1, // -1 means infinite
    this.particlesPerSecond = 10,
  }) : elapsed = 0.0;

  /// Update the emitter
  void update(double deltaTime) {
    if (!isActive) return;

    elapsed += deltaTime;
    
    // Check if emitter should finish
    if (duration > 0 && elapsed >= duration) {
      isActive = false;
      return;
    }

    // Emit particles based on rate
    _accumulator += particlesPerSecond * deltaTime;
    while (_accumulator >= 1.0) {
      emitParticle();
      _accumulator -= 1.0;
    }
  }

  /// Emit a single particle
  void emitParticle();

  /// Check if emitter is finished
  bool get isFinished => !isActive && (duration > 0 ? elapsed >= duration : false);

  /// Stop the emitter
  void stop() {
    isActive = false;
  }

  /// Start the emitter
  void start() {
    isActive = true;
    elapsed = 0.0;
    _accumulator = 0.0;
  }
}

/// Utility functions for particle effects
class ParticleUtils {
  static final math.Random _random = math.Random();

  /// Generate random offset within a circle
  static Offset randomInCircle(double radius) {
    final angle = _random.nextDouble() * 2 * math.pi;
    final distance = _random.nextDouble() * radius;
    return Offset(
      math.cos(angle) * distance,
      math.sin(angle) * distance,
    );
  }

  /// Generate random offset within a rectangle
  static Offset randomInRect(double width, double height) {
    return Offset(
      (_random.nextDouble() - 0.5) * width,
      (_random.nextDouble() - 0.5) * height,
    );
  }

  /// Generate random velocity in a cone
  static Offset randomVelocityInCone(double speed, double angleRadians, double coneAngle) {
    final angle = angleRadians + (_random.nextDouble() - 0.5) * coneAngle;
    final actualSpeed = speed * (0.5 + _random.nextDouble() * 0.5);
    return Offset(
      math.cos(angle) * actualSpeed,
      math.sin(angle) * actualSpeed,
    );
  }

  /// Interpolate between two colors
  static Color lerpColor(Color a, Color b, double t) {
    return Color.lerp(a, b, t.clamp(0.0, 1.0))!;
  }

  /// Generate random color variation
  static Color randomColorVariation(Color baseColor, double variation) {
    final r = (baseColor.red + (_random.nextDouble() - 0.5) * variation * 255).clamp(0, 255).round();
    final g = (baseColor.green + (_random.nextDouble() - 0.5) * variation * 255).clamp(0, 255).round();
    final b = (baseColor.blue + (_random.nextDouble() - 0.5) * variation * 255).clamp(0, 255).round();
    return Color.fromARGB(baseColor.alpha, r, g, b);
  }

  /// Apply easing function to value
  static double easeOut(double t) {
    return 1 - math.pow(1 - t, 3).toDouble();
  }

  static double easeIn(double t) {
    return t * t * t;
  }

  static double easeInOut(double t) {
    return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
  }
}