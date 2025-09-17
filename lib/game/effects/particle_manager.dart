import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'particle_engine.dart';
import 'basic_particles.dart';
import 'special_particles.dart';
import 'special_emitters.dart';

/// Premium particle manager for the game
class PremiumParticleManager {
  late ParticleSystem _particleSystem;
  final Map<String, ParticleEmitter> _namedEmitters = {};
  bool _isInitialized = false;

  // Performance settings
  int _maxParticles = 1000;
  bool _enableGlow = true;
  bool _enableTrails = true;
  double _qualityMultiplier = 1.0;

  /// Initialize the particle system
  void initialize({
    int maxParticles = 1000,
    bool enableGlow = true,
    bool enableTrails = true,
    double qualityMultiplier = 1.0,
  }) {
    _maxParticles = maxParticles;
    _enableGlow = enableGlow;
    _enableTrails = enableTrails;
    _qualityMultiplier = qualityMultiplier;

    _particleSystem = ParticleSystem();
    
    // Register particle pools
    _registerPools();
    
    _isInitialized = true;
  }

  void _registerPools() {
    // Basic particle pool
    _particleSystem.registerPool<BasicParticle>(
      ParticlePool<BasicParticle>(
        createParticle: BasicParticle.create,
        maxSize: (_maxParticles * 0.4).round(),
      ),
    );

    // Spark particle pool (if trails enabled)
    if (_enableTrails) {
      _particleSystem.registerPool<SparkParticle>(
        ParticlePool<SparkParticle>(
          createParticle: SparkParticle.create,
          maxSize: (_maxParticles * 0.15).round(),
        ),
      );
    }

    // Glow particle pool (if glow enabled)
    if (_enableGlow) {
      _particleSystem.registerPool<GlowParticle>(
        ParticlePool<GlowParticle>(
          createParticle: GlowParticle.create,
          maxSize: (_maxParticles * 0.15).round(),
        ),
      );
    }

    // Special particle pools
    _particleSystem.registerPool<ExplosionParticle>(
      ParticlePool<ExplosionParticle>(
        createParticle: ExplosionParticle.create,
        maxSize: (_maxParticles * 0.15).round(),
      ),
    );

    if (_enableTrails) {
      _particleSystem.registerPool<TrailParticle>(
        ParticlePool<TrailParticle>(
          createParticle: TrailParticle.create,
          maxSize: (_maxParticles * 0.1).round(),
        ),
      );
    }

    if (_enableGlow) {
      _particleSystem.registerPool<GlowParticle>(
        ParticlePool<GlowParticle>(
          createParticle: GlowParticle.create,
          maxSize: (_maxParticles * 0.05).round(),
        ),
      );
    }
  }

  /// Update all particles
  void update(double deltaTime) {
    if (!_isInitialized) return;
    _particleSystem.update(deltaTime * _qualityMultiplier);
  }

  /// Render all particles
  void render(Canvas canvas, Paint paint) {
    if (!_isInitialized) return;
    _particleSystem.render(canvas, paint);
  }

  /// Create explosion effect
  void createExplosion({
    required Offset position,
    Color color = Colors.orange,
    double intensity = 1.0,
    int particleCount = 20,
    ExplosionType type = ExplosionType.normal,
  }) {
    if (!_isInitialized) return;

    final adjustedCount = (particleCount * _qualityMultiplier).round();
    
    // Create explosion particles
    final explosionPool = _particleSystem.getPool<ExplosionParticle>();
    if (explosionPool != null) {
      for (int i = 0; i < adjustedCount; i++) {
        final particle = explosionPool.acquire();
        if (particle == null) break;

        final random = math.Random();
        final angle = random.nextDouble() * math.pi * 2;
        final speed = (50.0 + random.nextDouble() * 100.0) * intensity;
        
        particle.position = position + ParticleUtils.randomInCircle(5.0);
        particle.velocity = Offset(
          math.cos(angle) * speed,
          math.sin(angle) * speed,
        );
        
        // Set acceleration based on explosion type
        switch (type) {
          case ExplosionType.normal:
            particle.acceleration = const Offset(0, 50);
            break;
          case ExplosionType.fire:
            particle.acceleration = const Offset(0, -20);
            break;
          case ExplosionType.ice:
            particle.acceleration = const Offset(0, 30);
            break;
          case ExplosionType.electric:
            particle.acceleration = const Offset(0, 20);
            break;
        }
        
        particle.color = _getExplosionColor(type, color, random);
        particle.size = (2.0 + random.nextDouble() * 4.0) * intensity;
        particle.opacity = 1.0;
        particle.lifetime = ((30 + random.nextInt(60)) * intensity).round();
        particle.maxLifetime = particle.lifetime;
        particle.explosionType = type;
        particle.hasShockwave = random.nextDouble() < 0.4;
        particle.maxShockwaveRadius = (30.0 + random.nextDouble() * 40.0) * intensity;
        particle.shockwaveRadius = 0.0;
        particle.shockwaveOpacity = 1.0;
        particle.debrisRotation = random.nextDouble() * math.pi * 2;
        particle.debrisRotationSpeed = (random.nextDouble() - 0.5) * 0.3;
        particle.isActive = true;
      }
    }

    // Add sparks if enabled
    if (_enableTrails) {
      _createSparks(position, color, intensity, (adjustedCount * 0.3).round());
    }

    // Add glow if enabled
    if (_enableGlow) {
      _createGlow(position, color, intensity);
    }
  }

  Color _getExplosionColor(ExplosionType type, Color baseColor, math.Random random) {
    switch (type) {
      case ExplosionType.normal:
        return ParticleUtils.randomColorVariation(baseColor, 0.3);
      case ExplosionType.fire:
        final colors = [Colors.red, Colors.orange, Colors.yellow];
        return colors[random.nextInt(colors.length)];
      case ExplosionType.ice:
        final colors = [Colors.lightBlue, Colors.cyan, Colors.white];
        return colors[random.nextInt(colors.length)];
      case ExplosionType.electric:
        final colors = [Colors.yellow, Colors.white, Colors.lightBlue];
        return colors[random.nextInt(colors.length)];
    }
  }

  /// Create trail effect for drawing
  void createDrawingTrail({
    required Offset position,
    Color color = Colors.cyan,
    double intensity = 1.0,
    TrailType type = TrailType.smooth,
  }) {
    if (!_isInitialized) return;

    // Create trail particles
    if (_enableTrails) {
      final trailPool = _particleSystem.getPool<TrailParticle>();
      if (trailPool != null && math.Random().nextDouble() < 0.3 * _qualityMultiplier) {
        final particle = trailPool.acquire();
        if (particle != null) {
          final random = math.Random();
          
          particle.position = position + ParticleUtils.randomInCircle(2.0);
          particle.velocity = _getTrailVelocity(type, random, intensity);
          particle.acceleration = _getTrailAcceleration(type);
          particle.color = ParticleUtils.randomColorVariation(color, 0.1);
          particle.size = (1.5 + random.nextDouble() * 2.0) * intensity;
          particle.opacity = intensity;
          particle.lifetime = (60 + random.nextInt(90));
          particle.maxLifetime = particle.lifetime;
          particle.trailType = type;
          particle.trailWidth = 2.0 * intensity;
          particle.friction = _getTrailFriction(type);
          particle.waveAmplitude = _getWaveAmplitude(type);
          particle.waveFrequency = 0.05 + random.nextDouble() * 0.1;
          particle.trail.clear();
          particle.isActive = true;
        }
      }

      // Create sparks for electrical effect
      _createSparks(position, color, intensity, (3 * _qualityMultiplier).round());
    }

    // Create glow particles
    if (_enableGlow) {
      final glowPool = _particleSystem.getPool<GlowParticle>();
      if (glowPool != null) {
        final particle = glowPool.acquire();
        if (particle != null) {
          particle.position = position + ParticleUtils.randomInCircle(2.0);
          particle.velocity = ParticleUtils.randomVelocityInCone(20.0, -math.pi / 2, math.pi / 6);
          particle.acceleration = const Offset(0, -5);
          particle.color = color;
          particle.size = 1.5 + math.Random().nextDouble() * 2.0;
          particle.opacity = intensity;
          particle.lifetime = (40 + math.Random().nextInt(40));
          particle.maxLifetime = particle.lifetime;
          particle.pulseSpeed = 0.08;
          particle.pulseAmplitude = 0.5;
          particle.glowRadius = 4.0 + math.Random().nextDouble() * 4.0;
          particle.isActive = true;
        }
      }
    }
  }

  Offset _getTrailVelocity(TrailType type, math.Random random, double intensity) {
    final baseSpeed = 40.0 * intensity;
    final angle = random.nextDouble() * math.pi * 2;
    
    switch (type) {
      case TrailType.smooth:
        return Offset(
          math.cos(angle) * baseSpeed,
          math.sin(angle) * baseSpeed,
        );
      case TrailType.wavy:
        return Offset(
          math.cos(angle) * baseSpeed * 0.8,
          math.sin(angle) * baseSpeed * 0.8,
        );
      case TrailType.spiral:
        return Offset(
          math.cos(angle) * baseSpeed * 0.6,
          math.sin(angle) * baseSpeed * 0.6,
        );
      case TrailType.electric:
        return Offset(
          math.cos(angle) * baseSpeed * 1.2,
          math.sin(angle) * baseSpeed * 1.2,
        );
    }
  }

  Offset _getTrailAcceleration(TrailType type) {
    switch (type) {
      case TrailType.smooth:
        return const Offset(0, 20);
      case TrailType.wavy:
        return const Offset(0, 15);
      case TrailType.spiral:
        return const Offset(0, 10);
      case TrailType.electric:
        return const Offset(0, 25);
    }
  }

  double _getTrailFriction(TrailType type) {
    switch (type) {
      case TrailType.smooth:
        return 0.99;
      case TrailType.wavy:
        return 0.98;
      case TrailType.spiral:
        return 0.97;
      case TrailType.electric:
        return 0.96;
    }
  }

  double _getWaveAmplitude(TrailType type) {
    switch (type) {
      case TrailType.smooth:
        return 0.0;
      case TrailType.wavy:
        return 8.0;
      case TrailType.spiral:
        return 12.0;
      case TrailType.electric:
        return 5.0;
    }
  }

  /// Create score popup effect
  void createScoreEffect({
    required Offset position,
    Color color = Colors.yellow,
    double intensity = 1.0,
  }) {
    if (!_isInitialized) return;

    // Create upward floating particles
    final basicPool = _particleSystem.getPool<BasicParticle>();
    if (basicPool != null) {
      final count = (8 * _qualityMultiplier).round();
      for (int i = 0; i < count; i++) {
        final particle = basicPool.acquire();
        if (particle == null) break;

        final random = math.Random();
        
        particle.position = position + ParticleUtils.randomInCircle(10.0);
        particle.velocity = ParticleUtils.randomVelocityInCone(
          40.0 * intensity,
          -math.pi / 2, // Upward
          math.pi / 4,
        );
        particle.acceleration = const Offset(0, -20); // Float upward
        particle.color = color;
        particle.size = 2.0 + random.nextDouble() * 3.0;
        particle.opacity = 1.0;
        particle.lifetime = (60 + random.nextInt(60));
        particle.maxLifetime = particle.lifetime;
        particle.rotationSpeed = (random.nextDouble() - 0.5) * 0.1;
        particle.sizeDecay = 0.02;
        particle.isActive = true;
      }
    }

    // Add glow effect
    if (_enableGlow) {
      _createGlow(position, color, intensity);
    }
  }

  /// Create ambient particles for background
  void createAmbientEffect({
    required Offset position,
    Color color = Colors.white,
    double intensity = 0.5,
  }) {
    if (!_isInitialized) return;

    final basicPool = _particleSystem.getPool<BasicParticle>();
    if (basicPool != null && math.Random().nextDouble() < 0.1 * _qualityMultiplier) {
      final particle = basicPool.acquire();
      if (particle != null) {
        final random = math.Random();
        
        particle.position = position + ParticleUtils.randomInCircle(20.0);
        particle.velocity = ParticleUtils.randomVelocityInCone(
          10.0,
          random.nextDouble() * math.pi * 2,
          math.pi,
        );
        particle.acceleration = Offset.zero;
        particle.color = color.withOpacity(0.3);
        particle.size = 1.0 + random.nextDouble() * 2.0;
        particle.opacity = intensity;
        particle.lifetime = (120 + random.nextInt(120));
        particle.maxLifetime = particle.lifetime;
        particle.rotationSpeed = (random.nextDouble() - 0.5) * 0.05;
        particle.sizeDecay = 0.01;
        particle.isActive = true;
      }
    }
  }

  void _createSparks(Offset position, Color color, double intensity, int count) {
    final sparkPool = _particleSystem.getPool<SparkParticle>();
    if (sparkPool == null) return;

    for (int i = 0; i < count; i++) {
      final particle = sparkPool.acquire();
      if (particle == null) break;

      final random = math.Random();
      final angle = random.nextDouble() * math.pi * 2;
      final speed = 80.0 + random.nextDouble() * 60.0 * intensity;
      
      particle.position = position + ParticleUtils.randomInCircle(3.0);
      particle.velocity = Offset(
        math.cos(angle) * speed,
        math.sin(angle) * speed,
      );
      particle.acceleration = const Offset(0, 40);
      particle.color = color;
      particle.size = 1.0 + random.nextDouble() * 1.5;
      particle.opacity = 1.0;
      particle.lifetime = (15 + random.nextInt(25)) * intensity.round();
      particle.maxLifetime = particle.lifetime;
      particle.friction = 0.96;
      particle.trail.clear();
      particle.isActive = true;
    }
  }

  void _createGlow(Offset position, Color color, double intensity) {
    final glowPool = _particleSystem.getPool<GlowParticle>();
    if (glowPool == null) return;

    final count = (2 * _qualityMultiplier).round();
    for (int i = 0; i < count; i++) {
      final particle = glowPool.acquire();
      if (particle == null) break;

      final random = math.Random();
      
      particle.position = position + ParticleUtils.randomInCircle(8.0);
      particle.velocity = ParticleUtils.randomVelocityInCone(
        25.0,
        -math.pi / 2,
        math.pi / 2,
      );
      particle.acceleration = const Offset(0, -15);
      particle.color = color;
      particle.size = 3.0 + random.nextDouble() * 4.0;
      particle.opacity = intensity;
      particle.lifetime = (80 + random.nextInt(80));
      particle.maxLifetime = particle.lifetime;
      particle.pulseSpeed = 0.06 + random.nextDouble() * 0.08;
      particle.pulseAmplitude = 0.4 + random.nextDouble() * 0.3;
      particle.glowRadius = 8.0 + random.nextDouble() * 10.0;
      particle.isActive = true;
    }
  }

  /// Create continuous emitter
  void createEmitter({
    required String name,
    required Offset position,
    required ParticleEmitterType type,
    Color color = Colors.white,
    double intensity = 1.0,
    double duration = -1, // Infinite
    int particlesPerSecond = 10,
  }) {
    if (!_isInitialized) return;

    // Remove existing emitter with same name
    removeEmitter(name);

    ParticleEmitter? emitter;
    
    switch (type) {
      case ParticleEmitterType.basic:
        emitter = BasicParticleEmitter(
          particleSystem: _particleSystem,
          position: position,
          duration: duration,
          particlesPerSecond: (particlesPerSecond * _qualityMultiplier).round(),
          baseColor: color,
          baseSize: 2.0 * intensity,
          speedRange: 50.0 * intensity,
        );
        break;
      case ParticleEmitterType.spark:
        if (_enableTrails) {
          emitter = SparkEmitter(
            particleSystem: _particleSystem,
            position: position,
            duration: duration,
            particlesPerSecond: (particlesPerSecond * _qualityMultiplier).round(),
            sparkColor: color,
            intensity: intensity,
          );
        }
        break;
      case ParticleEmitterType.glow:
        if (_enableGlow) {
          emitter = GlowEmitter(
            particleSystem: _particleSystem,
            position: position,
            duration: duration,
            particlesPerSecond: (particlesPerSecond * _qualityMultiplier).round(),
            glowColor: color,
            glowIntensity: intensity,
          );
        }
        break;
      case ParticleEmitterType.explosion:
        emitter = ExplosionEmitter(
          particleSystem: _particleSystem,
          position: position,
          explosionType: ExplosionType.normal,
          intensity: intensity,
          explosionColor: color,
          particleCount: (20 * intensity).round(),
        );
        break;
      case ParticleEmitterType.trail:
        if (_enableTrails) {
          emitter = TrailEmitter(
            particleSystem: _particleSystem,
            position: position,
            duration: duration,
            particlesPerSecond: (particlesPerSecond * _qualityMultiplier).round(),
            trailType: TrailType.smooth,
            trailColor: color,
            trailIntensity: intensity,
          );
        }
        break;
      case ParticleEmitterType.enhancedGlow:
        if (_enableGlow) {
          emitter = EnhancedGlowEmitter(
            particleSystem: _particleSystem,
            position: position,
            duration: duration,
            particlesPerSecond: (particlesPerSecond * _qualityMultiplier).round(),
            glowType: GlowType.soft,
            glowColor: color,
            glowIntensity: intensity,
          );
        }
        break;
    }

    if (emitter != null) {
      _namedEmitters[name] = emitter;
      _particleSystem.addEmitter(emitter);
    }
  }

  /// Create composite effect
  void createCompositeEffect({
    required Offset position,
    required EffectComposition composition,
    double intensity = 1.0,
  }) {
    if (!_isInitialized) return;

    final emitter = CompositeEffectEmitter(
      particleSystem: _particleSystem,
      position: position,
      composition: composition,
      duration: 5.0, // Default duration
    );

    _particleSystem.addEmitter(emitter);
  }

  /// Create premium explosion with specific type
  void createPremiumExplosion({
    required Offset position,
    ExplosionType type = ExplosionType.normal,
    double intensity = 1.5,
    Color? color,
  }) {
    final explosionColor = color ?? _getDefaultExplosionColor(type);
    
    createExplosion(
      position: position,
      color: explosionColor,
      intensity: intensity,
      particleCount: (30 * intensity).round(),
      type: type,
    );
  }

  Color _getDefaultExplosionColor(ExplosionType type) {
    switch (type) {
      case ExplosionType.normal:
        return Colors.orange;
      case ExplosionType.fire:
        return Colors.red;
      case ExplosionType.ice:
        return Colors.lightBlue;
      case ExplosionType.electric:
        return Colors.yellow;
    }
  }

  /// Remove named emitter
  void removeEmitter(String name) {
    final emitter = _namedEmitters.remove(name);
    if (emitter != null) {
      emitter.stop();
      _particleSystem.removeEmitter(emitter);
    }
  }

  /// Update emitter position
  void updateEmitterPosition(String name, Offset position) {
    final emitter = _namedEmitters[name];
    if (emitter != null) {
      emitter.position = position;
    }
  }

  /// Set quality level (affects particle count and effects)
  void setQualityLevel(ParticleQualityLevel level) {
    switch (level) {
      case ParticleQualityLevel.low:
        _qualityMultiplier = 0.3;
        _enableGlow = false;
        _enableTrails = false;
        break;
      case ParticleQualityLevel.medium:
        _qualityMultiplier = 0.6;
        _enableGlow = true;
        _enableTrails = false;
        break;
      case ParticleQualityLevel.high:
        _qualityMultiplier = 0.8;
        _enableGlow = true;
        _enableTrails = true;
        break;
      case ParticleQualityLevel.ultra:
        _qualityMultiplier = 1.0;
        _enableGlow = true;
        _enableTrails = true;
        break;
    }

    // Reinitialize pools with new settings
    if (_isInitialized) {
      clearAll();
      _registerPools();
    }
  }

  /// Clear all particles and emitters
  void clearAll() {
    if (!_isInitialized) return;
    
    _particleSystem.clearAll();
    _namedEmitters.clear();
  }

  /// Get system statistics
  ParticleSystemStats get stats => _particleSystem.stats;

  /// Check if system is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose the particle system
  void dispose() {
    if (_isInitialized) {
      clearAll();
      _isInitialized = false;
    }
  }
}

/// Particle emitter types
enum ParticleEmitterType {
  basic,
  spark,
  glow,
  explosion,
  trail,
  enhancedGlow,
}

/// Quality levels for particle effects
enum ParticleQualityLevel {
  low,
  medium,
  high,
  ultra,
}