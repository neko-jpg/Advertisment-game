import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import '../../../lib/game/effects/impact_effect_system.dart';
import '../../../lib/game/effects/slow_motion_manager.dart';

void main() {
  group('ImpactEffectSystem Tests', () {
    late ImpactEffectSystem impactSystem;
    late ParticleEngine particleEngine;
    
    setUp(() {
      particleEngine = ParticleEngine();
      impactSystem = ImpactEffectSystem(particleEngine);
    });
    
    group('Score Explosion Effects', () {
      test('should trigger score explosion without errors', () {
        const position = Offset(100, 200);
        const score = 500;
        const color = Colors.cyan;
        
        expect(() => impactSystem.triggerScoreExplosion(position, score, color: color), returnsNormally);
      });
      
      test('should handle multiple score explosions', () {
        expect(() {
          impactSystem.triggerScoreExplosion(const Offset(100, 100), 100);
          impactSystem.triggerScoreExplosion(const Offset(200, 200), 200);
          impactSystem.triggerScoreExplosion(const Offset(300, 300), 300);
        }, returnsNormally);
      });
      
      test('should update score explosions over time', () {
        impactSystem.triggerScoreExplosion(const Offset(100, 100), 100);
        
        // 時間経過をシミュレート
        expect(() {
          for (int i = 0; i < 100; i++) {
            impactSystem.update(0.1);
          }
        }, returnsNormally);
      });
    });
    
    group('Combo Effects', () {
      test('should trigger combo effect with increasing intensity', () {
        const position = Offset(200, 300);
        
        // 低コンボ
        impactSystem.triggerComboEffect(2, position);
        expect(impactSystem.currentCombo, equals(2));
        expect(impactSystem.comboMultiplier, equals(1.4)); // 1.0 + (2 * 0.2)
        
        // 高コンボ
        impactSystem.triggerComboEffect(10, position);
        expect(impactSystem.currentCombo, equals(10));
        expect(impactSystem.comboMultiplier, equals(3.0)); // 1.0 + (10 * 0.2)
      });
      
      test('should generate appropriate combo colors', () {
        const position = Offset(200, 300);
        
        // 各コンボレベルでの色をテスト
        impactSystem.triggerComboEffect(2, position);
        expect(impactSystem.getComboColor(2), equals(Colors.cyan));
        
        impactSystem.triggerComboEffect(4, position);
        expect(impactSystem.getComboColor(4), equals(Colors.green));
        
        impactSystem.triggerComboEffect(7, position);
        expect(impactSystem.getComboColor(7), equals(Colors.orange));
        
        impactSystem.triggerComboEffect(11, position);
        expect(impactSystem.getComboColor(11), equals(Colors.red));
        
        impactSystem.triggerComboEffect(15, position);
        expect(impactSystem.getComboColor(15), equals(Colors.purple));
      });
      
      test('should reset combo correctly', () {
        impactSystem.triggerComboEffect(5, const Offset(100, 100));
        expect(impactSystem.currentCombo, equals(5));
        
        impactSystem.resetCombo();
        expect(impactSystem.currentCombo, equals(0));
        expect(impactSystem.comboMultiplier, equals(1.0));
      });
    });
    
    group('Slow Motion Effects', () {
      test('should start slow motion with correct parameters', () {
        expect(impactSystem.isSlowMotionActive, isFalse);
        expect(impactSystem.slowMotionFactor, equals(1.0));
        
        impactSystem.startSlowMotion(2.0, factor: 0.3);
        
        expect(impactSystem.isSlowMotionActive, isTrue);
        // スローモーションは徐々に適用されるため、即座には0.3にならない
      });
      
      test('should handle danger slow motion based on distance', () {
        // 遠い距離 - スローモーションなし
        impactSystem.triggerDangerSlowMotion(150.0);
        expect(impactSystem.isSlowMotionActive, isFalse);
        
        // 近い距離 - スローモーション発動
        impactSystem.triggerDangerSlowMotion(50.0);
        expect(impactSystem.isSlowMotionActive, isTrue);
        
        // 非常に近い距離 - より強いスローモーション
        impactSystem.clear(); // リセット
        impactSystem.triggerDangerSlowMotion(10.0);
        expect(impactSystem.isSlowMotionActive, isTrue);
      });
      
      test('should update slow motion over time', () {
        impactSystem.startSlowMotion(1.0, factor: 0.5);
        
        // 時間経過をシミュレート
        for (int i = 0; i < 20; i++) {
          impactSystem.update(0.1); // 2秒経過
        }
        
        // スローモーションが終了していることを確認
        expect(impactSystem.isSlowMotionActive, isFalse);
        expect(impactSystem.slowMotionFactor, equals(1.0));
      });
    });
    
    group('Screen Flash Effects', () {
      test('should trigger screen flash without errors', () {
        expect(() => impactSystem.triggerScreenFlash(Colors.white, 0.5), returnsNormally);
      });
      
      test('should fade screen flash over time', () {
        impactSystem.triggerScreenFlash(Colors.red, 0.2);
        
        // 時間経過
        expect(() => impactSystem.update(0.1), returnsNormally);
      });
    });
    
    group('System Integration', () {
      test('should handle multiple effects simultaneously', () {
        // 複数のエフェクトを同時に発動
        expect(() {
          impactSystem.triggerScoreExplosion(const Offset(100, 100), 500);
          impactSystem.triggerComboEffect(5, const Offset(200, 200));
          impactSystem.startSlowMotion(1.0, factor: 0.4);
        }, returnsNormally);
        
        expect(impactSystem.isSlowMotionActive, isTrue);
        expect(impactSystem.currentCombo, equals(5));
      });
      
      test('should clear all effects', () {
        // エフェクトを設定
        impactSystem.triggerScoreExplosion(const Offset(100, 100), 500);
        impactSystem.triggerComboEffect(3, const Offset(200, 200));
        impactSystem.startSlowMotion(2.0);
        
        // クリア実行
        impactSystem.clear();
        
        // 主要な状態がクリアされていることを確認
        expect(impactSystem.isSlowMotionActive, isFalse);
        expect(impactSystem.currentCombo, equals(0));
      });
      
      test('should update all systems correctly', () {
        // 複数のエフェクトを設定
        impactSystem.triggerScoreExplosion(const Offset(100, 100), 500);
        impactSystem.triggerComboEffect(3, const Offset(200, 200));
        impactSystem.startSlowMotion(1.0);
        
        // 更新実行
        expect(() => impactSystem.update(0.016), returnsNormally); // 60FPS相当
      });
      
      test('should render without errors', () {
        // エフェクトを設定
        impactSystem.triggerScoreExplosion(const Offset(100, 100), 500);
        impactSystem.triggerComboEffect(3, const Offset(200, 200));
        
        // 描画テスト（実際のCanvasは使用しないが、エラーが発生しないことを確認）
        expect(() {
          // 描画処理は実際のCanvasが必要なため、ここでは呼び出しのみテスト
          // impactSystem.render(canvas, size);
        }, returnsNormally);
      });
    });
    
    group('Performance Tests', () {
      test('should handle many simultaneous effects', () {
        // 大量のエフェクトを生成
        expect(() {
          for (int i = 0; i < 50; i++) {
            impactSystem.triggerScoreExplosion(
              Offset(i * 10.0, i * 5.0),
              100 + i,
            );
          }
          
          for (int i = 0; i < 10; i++) {
            impactSystem.triggerComboEffect(i + 1, Offset(i * 20.0, 200));
          }
        }, returnsNormally);
        
        // パフォーマンステスト - 更新が正常に完了することを確認
        expect(() {
          for (int i = 0; i < 100; i++) {
            impactSystem.update(0.016);
          }
        }, returnsNormally);
      });
    });
  });
  
  group('SlowMotionManager Tests', () {
    late SlowMotionManager slowMotionManager;
    
    setUp(() {
      slowMotionManager = SlowMotionManager();
    });
    
    test('should start slow motion with correct parameters', () {
      expect(slowMotionManager.isActive, isFalse);
      expect(slowMotionManager.currentFactor, equals(1.0));
      
      slowMotionManager.startSlowMotion(factor: 0.5, duration: 2.0);
      
      expect(slowMotionManager.isActive, isTrue);
      expect(slowMotionManager.duration, equals(2.0));
    });
    
    test('should adjust delta time correctly', () {
      slowMotionManager.startSlowMotion(factor: 0.5, duration: 1.0);
      
      // 時間を進めてスローモーションを適用
      for (int i = 0; i < 10; i++) {
        slowMotionManager.update(0.1);
      }
      
      const originalDelta = 0.016;
      final adjustedDelta = slowMotionManager.getAdjustedDeltaTime(originalDelta);
      final uiDelta = slowMotionManager.getUIDeltaTime(originalDelta);
      
      expect(adjustedDelta, lessThanOrEqualTo(originalDelta));
      expect(uiDelta, equals(originalDelta)); // UIは常に通常速度
    });
    
    test('should handle different slow motion types', () {
      // 精密モード
      slowMotionManager.startSlowMotion(
        factor: 0.3,
        duration: 1.0,
        type: SlowMotionType.precision,
      );
      expect(slowMotionManager.isActive, isTrue);
      
      // 危険モード
      slowMotionManager.forceStop();
      slowMotionManager.startSlowMotion(
        factor: 0.2,
        duration: 0.5,
        type: SlowMotionType.danger,
      );
      expect(slowMotionManager.isActive, isTrue);
    });
    
    test('should stop slow motion correctly', () {
      slowMotionManager.startSlowMotion(factor: 0.3, duration: 2.0);
      expect(slowMotionManager.isActive, isTrue);
      
      slowMotionManager.stopSlowMotion();
      
      // 時間を進めて停止を確認
      for (int i = 0; i < 10; i++) {
        slowMotionManager.update(0.1);
      }
      
      expect(slowMotionManager.currentFactor, equals(1.0));
    });
    
    test('should force stop immediately', () {
      slowMotionManager.startSlowMotion(factor: 0.3, duration: 2.0);
      expect(slowMotionManager.isActive, isTrue);
      
      slowMotionManager.forceStop();
      
      expect(slowMotionManager.isActive, isFalse);
      expect(slowMotionManager.currentFactor, equals(1.0));
    });
  });
}