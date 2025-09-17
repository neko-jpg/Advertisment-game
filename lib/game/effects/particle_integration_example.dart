import 'package:flutter/material.dart';
import 'particle_manager.dart';
import 'special_particles.dart';

/// Example integration showing how to use the premium particle system in the game
class ParticleIntegrationExample {
  late PremiumParticleManager _particleManager;
  
  void initialize() {
    _particleManager = PremiumParticleManager();
    _particleManager.initialize(
      maxParticles: 1000,
      enableGlow: true,
      enableTrails: true,
      qualityMultiplier: 1.0,
    );
  }

  /// Example: Player draws a line - create trail effect
  void onPlayerDrawLine(Offset position, {bool isSpecialLine = false}) {
    if (isSpecialLine) {
      // Electric trail for special lines
      _particleManager.createDrawingTrail(
        position: position,
        color: Colors.yellow,
        intensity: 1.5,
        type: TrailType.electric,
      );
    } else {
      // Normal smooth trail
      _particleManager.createDrawingTrail(
        position: position,
        color: Colors.cyan,
        intensity: 1.0,
        type: TrailType.smooth,
      );
    }
  }

  /// Example: Player collects coin - create score effect
  void onCoinCollected(Offset position, int coinValue) {
    _particleManager.createScoreEffect(
      position: position,
      color: coinValue > 1 ? Colors.gold : Colors.yellow,
      intensity: coinValue > 1 ? 1.5 : 1.0,
    );
  }

  /// Example: Enemy defeated - create explosion
  void onEnemyDefeated(Offset position, {String enemyType = 'normal'}) {
    switch (enemyType) {
      case 'fire':
        _particleManager.createPremiumExplosion(
          position: position,
          type: ExplosionType.fire,
          intensity: 1.8,
        );
        break;
      case 'ice':
        _particleManager.createPremiumExplosion(
          position: position,
          type: ExplosionType.ice,
          intensity: 1.5,
        );
        break;
      case 'electric':
        _particleManager.createCompositeEffect(
          position: position,
          composition: EffectComposition.electricStorm,
          intensity: 2.0,
        );
        break;
      default:
        _particleManager.createExplosion(
          position: position,
          color: Colors.orange,
          intensity: 1.2,
          particleCount: 25,
        );
    }
  }

  /// Example: Boss defeated - create massive effect
  void onBossDefeated(Offset position) {
    _particleManager.createCompositeEffect(
      position: position,
      composition: EffectComposition.magicalBurst,
      intensity: 3.0,
    );
  }

  /// Example: Power-up collected - create glow effect
  void onPowerUpCollected(Offset position, String powerUpType) {
    switch (powerUpType) {
      case 'shield':
        _particleManager.createEmitter(
          name: 'shield_glow',
          position: position,
          type: ParticleEmitterType.enhancedGlow,
          color: Colors.blue,
          intensity: 1.5,
          duration: 3.0,
          particlesPerSecond: 20,
        );
        break;
      case 'speed':
        _particleManager.createEmitter(
          name: 'speed_trail',
          position: position,
          type: ParticleEmitterType.trail,
          color: Colors.green,
          intensity: 2.0,
          duration: 2.0,
          particlesPerSecond: 30,
        );
        break;
      case 'magnet':
        _particleManager.createEmitter(
          name: 'magnet_aura',
          position: position,
          type: ParticleEmitterType.enhancedGlow,
          color: Colors.purple,
          intensity: 1.8,
          duration: 4.0,
          particlesPerSecond: 15,
        );
        break;
    }
  }

  /// Example: Ambient background effects
  void createAmbientEffects(Size screenSize) {
    // Create floating ambient particles
    for (int i = 0; i < 5; i++) {
      final position = Offset(
        (i + 1) * screenSize.width / 6,
        screenSize.height * 0.3,
      );
      
      _particleManager.createAmbientEffect(
        position: position,
        color: Colors.white.withOpacity(0.3),
        intensity: 0.5,
      );
    }
  }

  /// Update particles (call this in game loop)
  void update(double deltaTime) {
    _particleManager.update(deltaTime);
  }

  /// Render particles (call this in paint method)
  void render(Canvas canvas, Paint paint) {
    _particleManager.render(canvas, paint);
  }

  /// Set quality based on device performance
  void setQualityLevel(String devicePerformance) {
    ParticleQualityLevel level;
    switch (devicePerformance) {
      case 'low':
        level = ParticleQualityLevel.low;
        break;
      case 'medium':
        level = ParticleQualityLevel.medium;
        break;
      case 'high':
        level = ParticleQualityLevel.high;
        break;
      case 'ultra':
        level = ParticleQualityLevel.ultra;
        break;
      default:
        level = ParticleQualityLevel.medium;
    }
    
    _particleManager.setQualityLevel(level);
  }

  /// Get performance statistics
  String getPerformanceStats() {
    final stats = _particleManager.stats;
    return 'Active: ${stats.totalActive}, '
           'Available: ${stats.totalAvailable}, '
           'Emitters: ${stats.emitterCount}, '
           'Utilization: ${(stats.systemUtilization * 100).toStringAsFixed(1)}%';
  }

  /// Clean up
  void dispose() {
    _particleManager.dispose();
  }
}

/// Widget that demonstrates the particle system
class ParticleSystemDemo extends StatefulWidget {
  const ParticleSystemDemo({super.key});

  @override
  State<ParticleSystemDemo> createState() => _ParticleSystemDemoState();
}

class _ParticleSystemDemoState extends State<ParticleSystemDemo>
    with TickerProviderStateMixin {
  late ParticleIntegrationExample _particleExample;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _particleExample = ParticleIntegrationExample();
    _particleExample.initialize();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    );
    
    _animationController.addListener(() {
      _particleExample.update(0.016); // 60 FPS
      setState(() {});
    });
    
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _particleExample.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Particle System Demo'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          // Create explosion at tap position
          _particleExample.onEnemyDefeated(
            details.localPosition,
            enemyType: 'electric',
          );
        },
        onPanUpdate: (details) {
          // Create trail while dragging
          _particleExample.onPlayerDrawLine(
            details.localPosition,
            isSpecialLine: true,
          );
        },
        child: CustomPaint(
          painter: ParticlePainter(_particleExample),
          size: Size.infinite,
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'explosion',
            onPressed: () {
              _particleExample.onBossDefeated(
                Offset(MediaQuery.of(context).size.width / 2, 200),
              );
            },
            child: const Icon(Icons.whatshot),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'coin',
            onPressed: () {
              _particleExample.onCoinCollected(
                Offset(MediaQuery.of(context).size.width / 2, 300),
                3, // High value coin
              );
            },
            child: const Icon(Icons.monetization_on),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'powerup',
            onPressed: () {
              _particleExample.onPowerUpCollected(
                Offset(MediaQuery.of(context).size.width / 2, 400),
                'shield',
              );
            },
            child: const Icon(Icons.shield),
          ),
        ],
      ),
    );
  }
}

class ParticlePainter extends CustomPainter {
  final ParticleIntegrationExample particleExample;

  ParticlePainter(this.particleExample);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    particleExample.render(canvas, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}