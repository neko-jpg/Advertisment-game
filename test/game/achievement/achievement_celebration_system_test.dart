import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/game/achievement/achievement_celebration_system.dart';
import '../../../lib/game/achievement/achievement_manager.dart';
import '../../../lib/game/achievement/celebration_particles.dart';
import '../../../lib/game/effects/impact_effect_system.dart';

void main() {
  group('AchievementCelebrationSystem Tests', () {
    late AchievementCelebrationSystem celebrationSystem;
    late ParticleEngine particleEngine;
    
    setUp(() {
      particleEngine = ParticleEngine();
      celebrationSystem = AchievementCelebrationSystem(
        particleEngine: particleEngine,
      );
    });
    
    testWidgets('新記録達成時の祝福演出が正常に動作する', (WidgetTester tester) async {
      // テスト用のウィジェット作成
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    await celebrationSystem.celebrateNewRecord(
                      newScore: 1500,
                      previousRecord: 1000,
                      context: context,
                    );
                  },
                  child: const Text('Celebrate'),
                );
              },
            ),
          ),
        ),
      );
      
      // 祝福演出開始前の状態確認
      expect(celebrationSystem.isCelebrating, false);
      
      // 祝福ボタンをタップ
      await tester.tap(find.text('Celebrate'));
      await tester.pump();
      
      // 祝福演出が開始されることを確認
      expect(celebrationSystem.isCelebrating, true);
      
      // ダイアログが表示されることを確認
      await tester.pumpAndSettle();
      expect(find.byType(RecordAchievementDialog), findsOneWidget);
      
      // スコア表示の確認
      expect(find.text('1500'), findsOneWidget);
      expect(find.text('+500点 向上！'), findsOneWidget);
      expect(find.text('前回記録: 1000'), findsOneWidget);
    });
    
    testWidgets('記録達成ダイアログのアニメーションが正常に動作する', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RecordAchievementDialog(
            newScore: 2000,
            previousRecord: 1500,
            onShare: () {},
            onContinue: () {},
          ),
        ),
      );
      
      // 初期状態でダイアログが存在することを確認
      expect(find.byType(RecordAchievementDialog), findsOneWidget);
      
      // アニメーションの進行を確認
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      
      // 最終状態でボタンが表示されることを確認
      expect(find.text('シェア'), findsOneWidget);
      expect(find.text('続ける'), findsOneWidget);
    });
    
    test('祝福演出の状態が正しく管理される', () {
      // 祝福演出開始前
      expect(celebrationSystem.isCelebrating, false);
      
      // 祝福演出の経過時間は非公開フィールドなのでテストしない
      // 代わりに公開されている状態のみテスト
      expect(celebrationSystem.celebrationDuration, null);
    });
  });
  
  group('AchievementManager Tests', () {
    late AchievementManager achievementManager;
    late ParticleEngine particleEngine;
    
    setUp(() {
      particleEngine = ParticleEngine();
      achievementManager = AchievementManager(
        particleEngine: particleEngine,
      );
    });
    
    test('スコア更新が正常に動作する', () {
      // 初期状態の確認
      expect(achievementManager.currentScore, 0);
      expect(achievementManager.bestScore, 0);
      expect(achievementManager.hasNewRecord, false);
      
      // スコア更新
      achievementManager.updateScore(500);
      
      // 状態の確認
      expect(achievementManager.currentScore, 500);
      expect(achievementManager.bestScore, 500);
      expect(achievementManager.hasNewRecord, true);
    });
    
    test('新記録検出が正常に動作する', () {
      bool recordCallbackCalled = false;
      int callbackNewScore = 0;
      int callbackPreviousRecord = 0;
      
      // コールバック設定
      achievementManager.onNewRecord = (newScore, previousRecord) {
        recordCallbackCalled = true;
        callbackNewScore = newScore;
        callbackPreviousRecord = previousRecord;
      };
      
      // 初回スコア設定
      achievementManager.updateScore(1000);
      expect(recordCallbackCalled, true);
      expect(callbackNewScore, 1000);
      expect(callbackPreviousRecord, 0);
      
      // 記録更新
      recordCallbackCalled = false;
      achievementManager.updateScore(1500);
      expect(recordCallbackCalled, true);
      expect(callbackNewScore, 1500);
      expect(callbackPreviousRecord, 1000);
      
      // 記録未更新
      recordCallbackCalled = false;
      achievementManager.updateScore(1200);
      expect(recordCallbackCalled, false);
    });
    
    test('セッション記録が正常に管理される', () {
      // セッション記録の更新
      achievementManager.updateScore(800);
      expect(achievementManager.sessionBestScore, 800);
      expect(achievementManager.hasSessionRecord, true);
      
      // より高いスコア
      achievementManager.updateScore(1200);
      expect(achievementManager.sessionBestScore, 1200);
      
      // より低いスコア（セッション記録は変わらない）
      achievementManager.updateScore(900);
      expect(achievementManager.sessionBestScore, 1200);
    });
    
    test('記録リセットが正常に動作する', () {
      // 記録設定
      achievementManager.updateScore(1500);
      expect(achievementManager.bestScore, 1500);
      expect(achievementManager.hasNewRecord, true);
      
      // リセット実行
      achievementManager.resetRecords();
      
      // リセット後の確認
      expect(achievementManager.currentScore, 0);
      expect(achievementManager.bestScore, 0);
      expect(achievementManager.sessionBestScore, 0);
      expect(achievementManager.hasNewRecord, false);
      expect(achievementManager.hasSessionRecord, false);
    });
  });
  
  group('CelebrationParticles Tests', () {
    test('祝福星形パーティクルが正常に初期化される', () {
      final star = CelebrationStarParticle(
        position: const Offset(400, 300),
        velocity: const Offset(50, -100),
        color: const Color(0xFFFFD700),
        size: 8.0,
        lifetime: 120,
      );
      
      expect(star.position, const Offset(400, 300));
      expect(star.velocity, const Offset(50, -100));
      expect(star.color, const Color(0xFFFFD700));
      expect(star.size, 8.0);
      expect(star.lifetime, 120);
    });
    
    test('紙吹雪パーティクルが正常に生成される', () {
      final confetti = ConfettiParticle(
        position: const Offset(100, 50),
        velocity: const Offset(20, 80),
        color: Colors.red,
        lifetime: 180,
      );
      
      expect(confetti.position, const Offset(100, 50));
      expect(confetti.velocity, const Offset(20, 80));
      expect(confetti.color, Colors.red);
      expect(confetti.lifetime, 180);
    });
    
    test('フラッシュパーティクルが正常に動作する', () {
      final flash = FlashParticle(
        position: Offset.zero,
        color: Colors.white,
        lifetime: 30,
        intensity: 0.8,
      );
      
      expect(flash.position, Offset.zero);
      expect(flash.color, Colors.white);
      expect(flash.lifetime, 30);
      
      // 時間経過テスト
      flash.update(0.016); // 1フレーム経過
      expect(flash.lifetime, 29);
      expect(flash.isActive, true);
    });
    
    test('衝撃波パーティクルが正常に動作する', () {
      final shockwave = ShockwaveParticle(
        position: const Offset(300, 400),
        color: const Color(0xFF00D4FF),
        lifetime: 60,
        maxRadius: 500,
      );
      
      expect(shockwave.position, const Offset(300, 400));
      expect(shockwave.color, const Color(0xFF00D4FF));
      expect(shockwave.lifetime, 60);
      
      // 更新テスト
      shockwave.update(0.016); // 1フレーム経過
      expect(shockwave.lifetime, 59);
      expect(shockwave.isActive, true);
    });
  });
  
  group('Integration Tests', () {
    testWidgets('達成システム全体の統合テスト', (WidgetTester tester) async {
      final particleEngine = ParticleEngine();
      final achievementManager = AchievementManager(
        particleEngine: particleEngine,
      );
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        achievementManager.updateScore(1500);
                      },
                      child: const Text('Update Score'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await achievementManager.checkAchievements(context);
                      },
                      child: const Text('Check Achievements'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      
      // スコア更新
      await tester.tap(find.text('Update Score'));
      await tester.pump();
      
      expect(achievementManager.hasNewRecord, true);
      expect(achievementManager.bestScore, 1500);
      
      // 達成チェック実行
      await tester.tap(find.text('Check Achievements'));
      await tester.pump();
      
      // 祝福ダイアログが表示されることを確認
      await tester.pumpAndSettle();
      expect(find.byType(RecordAchievementDialog), findsOneWidget);
    });
  });
}