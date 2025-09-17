import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'particle_engine.dart';
import 'special_particles.dart';
import 'score_explosion.dart';
import 'combo_effect.dart';
import 'slow_motion_manager.dart';

/// Simple wrapper for ParticleSystem to maintain compatibility
class ParticleEngine {
  final ParticleSystem _system = ParticleSystem();
  
  ParticleEngine() {
    // Initialize with explosion particle pool
    _system.registerPool(ParticlePool<ExplosionParticle>(
      createParticle: () => ExplosionParticle(
        position: Offset.zero,
        velocity: Offset.zero,
        color: Colors.white,
        size: 4.0,
        lifetime: 60,
      ),
      maxSize: 500,
    ));
  }
  
  void emit(ParticleEmitter emitter) {
    _system.addEmitter(emitter);
  }
  
  void update(double deltaTime) {
    _system.update(deltaTime);
  }
  
  void render(Canvas canvas, Size size) {
    final paint = Paint();
    _system.render(canvas, paint);
  }
  
  void clear() {
    _system.clearAll();
  }
}

/// Explosion particle emitter for impact effects
class ExplosionParticles extends ParticleEmitter {
  final int particleCount;
  final Color color;
  final double intensity;
  final double spread;
  int _emittedCount = 0;
  
  ExplosionParticles({
    required Offset position,
    required this.particleCount,
    required this.color,
    this.intensity = 1.0,
    this.spread = 100.0,
  }) : super(
    position: position,
    duration: 0.1, // Quick burst
    particlesPerSecond: particleCount * 10, // Emit all particles quickly
  );
  
  @override
  void emitParticle() {
    if (_emittedCount >= particleCount) {
      stop();
      return;
    }
    
    // This would normally create particles, but for now we'll just track count
    _emittedCount++;
  }
}

/// インパクトエフェクトシステム - スコア獲得、コンボ、スローモーション効果を管理
class ImpactEffectSystem {
  final ParticleEngine _particleEngine;
  final SlowMotionManager _slowMotionManager;
  final List<ScoreExplosion> _activeScoreExplosions = [];
  final List<ComboEffect> _activeComboEffects = [];
  
  // 画面フラッシュ効果
  double _screenFlashIntensity = 0.0;
  Color _screenFlashColor = Colors.white;
  
  // コンボ状態
  int _currentCombo = 0;
  double _comboMultiplier = 1.0;
  
  ImpactEffectSystem(this._particleEngine) : _slowMotionManager = SlowMotionManager();
  
  /// スコア獲得時の爆発エフェクトをトリガー
  void triggerScoreExplosion(Offset position, int score, {Color? color}) {
    // 爆発パーティクル生成
    _particleEngine.emit(
      ExplosionParticles(
        position: position,
        particleCount: math.min(20 + (score ~/ 100), 50),
        color: color ?? Colors.cyan,
        intensity: math.min(1.0 + (score / 1000), 3.0),
      ),
    );
    
    // スコア数字アニメーション
    final explosion = ScoreExplosion(
      position: position,
      score: score,
      color: color ?? Colors.cyan,
    );
    _activeScoreExplosions.add(explosion);
    
    // 画面フラッシュ
    triggerScreenFlash(Colors.white.withOpacity(0.3), 0.1);
    
    // 振動フィードバック（実装時に有効化）
    // HapticFeedback.lightImpact();
  }
  
  /// コンボエフェクトをトリガー
  void triggerComboEffect(int comboCount, Offset position) {
    _currentCombo = comboCount;
    _comboMultiplier = 1.0 + (comboCount * 0.2);
    
    // コンボ数に応じたエフェクト強化
    final intensity = math.min(comboCount / 10.0, 2.0);
    final particleCount = math.min(30 + (comboCount * 5), 100);
    
    // 画面全体エフェクト
    final comboEffect = ComboEffect(
      comboCount: comboCount,
      intensity: intensity,
      centerPosition: position,
    );
    _activeComboEffects.add(comboEffect);
    
    // 強化された爆発エフェクト
    _particleEngine.emit(
      ExplosionParticles(
        position: position,
        particleCount: particleCount,
        color: getComboColor(comboCount),
        intensity: intensity,
        spread: 150.0 + (comboCount * 10),
      ),
    );
    
    // 画面全体フラッシュ
    triggerScreenFlash(getComboColor(comboCount).withOpacity(0.4), 0.2);
    
    // 強い振動フィードバック（実装時に有効化）
    // if (comboCount >= 5) {
    //   HapticFeedback.mediumImpact();
    // }
    // if (comboCount >= 10) {
    //   HapticFeedback.heavyImpact();
    // }
  }
  
  /// スローモーション効果を開始
  void startSlowMotion(double duration, {double factor = 0.3, SlowMotionType type = SlowMotionType.precision}) {
    _slowMotionManager.startSlowMotion(
      factor: factor,
      duration: duration,
      type: type,
    );
    
    // スローモーション開始の視覚効果
    triggerScreenFlash(Colors.blue.withOpacity(0.2), 0.3);
  }
  
  /// 障害物接近時のスローモーション
  void triggerDangerSlowMotion(double distance) {
    // 距離に応じてスローモーション強度を調整
    final intensity = math.max(0.0, 1.0 - (distance / 100.0));
    if (intensity > 0.3) {
      final factor = 0.2 + (intensity * 0.3); // 0.2-0.5の範囲
      startSlowMotion(1.0, factor: factor, type: SlowMotionType.danger);
    }
  }
  
  /// 画面フラッシュ効果をトリガー
  void triggerScreenFlash(Color color, double duration) {
    _screenFlashColor = color;
    _screenFlashIntensity = 1.0;
  }
  
  /// コンボ数に応じた色を取得
  Color getComboColor(int combo) {
    if (combo < 3) return Colors.cyan;
    if (combo < 5) return Colors.green;
    if (combo < 8) return Colors.orange;
    if (combo < 12) return Colors.red;
    return Colors.purple;
  }
  
  /// システム更新
  void update(double deltaTime) {
    // スローモーション管理更新
    _slowMotionManager.update(deltaTime);
    final adjustedDeltaTime = _slowMotionManager.getAdjustedDeltaTime(deltaTime);
    
    // スコア爆発エフェクト更新
    _activeScoreExplosions.removeWhere((explosion) {
      explosion.update(adjustedDeltaTime);
      return explosion.isComplete;
    });
    
    // コンボエフェクト更新
    _activeComboEffects.removeWhere((effect) {
      effect.update(adjustedDeltaTime);
      return effect.isComplete;
    });
    
    // 画面フラッシュ減衰（UI速度で更新）
    if (_screenFlashIntensity > 0) {
      final uiDeltaTime = _slowMotionManager.getUIDeltaTime(deltaTime);
      _screenFlashIntensity = math.max(0, _screenFlashIntensity - uiDeltaTime * 5);
    }
  }
  
  /// エフェクトを描画
  void render(Canvas canvas, Size size) {
    // スローモーション視覚効果
    _slowMotionManager.renderEffects(canvas, size);
    
    // 画面フラッシュ描画
    if (_screenFlashIntensity > 0) {
      final paint = Paint()
        ..color = _screenFlashColor.withOpacity(_screenFlashIntensity)
        ..blendMode = BlendMode.screen;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }
    
    // スコア爆発描画
    for (final explosion in _activeScoreExplosions) {
      explosion.render(canvas);
    }
    
    // コンボエフェクト描画
    for (final effect in _activeComboEffects) {
      effect.render(canvas, size);
    }
  }
  
  // Getters
  bool get isSlowMotionActive => _slowMotionManager.isActive;
  double get slowMotionFactor => _slowMotionManager.currentFactor;
  int get currentCombo => _currentCombo;
  double get comboMultiplier => _comboMultiplier;
  SlowMotionManager get slowMotionManager => _slowMotionManager;
  
  /// コンボリセット
  void resetCombo() {
    _currentCombo = 0;
    _comboMultiplier = 1.0;
  }
  
  /// 全エフェクトクリア
  void clear() {
    _activeScoreExplosions.clear();
    _activeComboEffects.clear();
    _slowMotionManager.forceStop();
    _screenFlashIntensity = 0.0;
    resetCombo();
  }
}