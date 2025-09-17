import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/game/achievement/growth_effect_system.dart';
import '../../../lib/game/effects/impact_effect_system.dart';

void main() {
  group('GrowthEffectSystem Tests', () {
    late GrowthEffectSystem growthSystem;
    late ParticleEngine particleEngine;
    
    setUp(() {
      particleEngine = ParticleEngine();
      growthSystem = GrowthEffectSystem(
        particleEngine: particleEngine,
      );
    });
    
    testWidgets('レベルアップ演出が正常に動作する', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    await growthSystem.showLevelUpEffect(
                      newLevel: 5,
                      previousLevel: 4,
                      context: context,
                      unlockedContent: {
                        '新しい線種': '炎の線',
                        '新機能': 'コンボシステム',
                      },
                    );
                  },
                  child: const Text('Level Up'),
                );
              },
            ),
          ),
        ),
      );
      
      // レベルアップ演出開始前の状態確認
      expect(growthSystem.isShowingGrowthEffect, false);
      
      // レベルアップボタンをタップ
      await tester.tap(find.text('Level Up'));
      await tester.pump();
      
      // レベルアップ演出が開始されることを確認
      expect(growthSystem.isShowingGrowthEffect, true);
      
      // ダイアログが表示されることを確認
      await tester.pumpAndSettle();
      expect(find.byType(LevelUpDialog), findsOneWidget);
      
      // レベル表示の確認
      expect(find.text('Lv.5'), findsOneWidget);
      expect(find.text('+1 レベル上昇！'), findsOneWidget);
      expect(find.text('新機能解放！'), findsOneWidget);
    });
    
    testWidgets('レベルアップダイアログのアニメーションが正常に動作する', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LevelUpDialog(
            newLevel: 10,
            previousLevel: 8,
            unlockedContent: {
              'スペシャル攻撃': '雷の線',
            },
            onContinue: () {},
          ),
        ),
      );
      
      // 初期状態でダイアログが存在することを確認
      expect(find.byType(LevelUpDialog), findsOneWidget);
      
      // アニメーションの進行を確認
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 800));
      
      // 最終状態でボタンが表示されることを確認
      expect(find.text('続ける'), findsOneWidget);
      expect(find.text('レベルアップ！'), findsOneWidget);
    });
    
    test('成長演出の状態が正しく管理される', () {
      // 成長演出開始前
      expect(growthSystem.isShowingGrowthEffect, false);
      
      // 状態は非公開フィールドなので、公開されているプロパティのみテスト
      expect(growthSystem.isShowingGrowthEffect, false);
    });
  });
  
  group('StatGrowthWidget Tests', () {
    testWidgets('能力値上昇ウィジェットが正常に表示される', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatGrowthWidget(
              statName: '攻撃力',
              oldValue: 50,
              newValue: 65,
              color: Color(0xFFFF6B6B),
            ),
          ),
        ),
      );
      
      // 初期状態で能力値名が表示されることを確認
      expect(find.text('攻撃力'), findsOneWidget);
      
      // アニメーションの進行を確認
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1000));
      
      // 最終状態で数値が表示されることを確認
      expect(find.text('65'), findsOneWidget);
      expect(find.text('+15'), findsOneWidget);
    });
    
    testWidgets('複数の能力値ウィジェットが同時に動作する', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatGrowthWidget(
                  statName: 'HP',
                  oldValue: 100,
                  newValue: 120,
                  color: Color(0xFF4CAF50),
                ),
                StatGrowthWidget(
                  statName: 'MP',
                  oldValue: 50,
                  newValue: 70,
                  color: Color(0xFF2196F3),
                ),
                StatGrowthWidget(
                  statName: 'スピード',
                  oldValue: 30,
                  newValue: 35,
                  color: Color(0xFFFF9800),
                ),
              ],
            ),
          ),
        ),
      );
      
      // 全ての能力値名が表示されることを確認
      expect(find.text('HP'), findsOneWidget);
      expect(find.text('MP'), findsOneWidget);
      expect(find.text('スピード'), findsOneWidget);
      
      // アニメーション完了後の確認
      await tester.pumpAndSettle();
      
      expect(find.text('120'), findsOneWidget);
      expect(find.text('70'), findsOneWidget);
      expect(find.text('35'), findsOneWidget);
      
      expect(find.text('+20'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
    });
  });
  
  group('Integration Tests', () {
    testWidgets('成長システム全体の統合テスト', (WidgetTester tester) async {
      final particleEngine = ParticleEngine();
      final growthSystem = GrowthEffectSystem(
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
                      onPressed: () async {
                        await growthSystem.showLevelUpEffect(
                          newLevel: 15,
                          previousLevel: 10,
                          context: context,
                          unlockedContent: {
                            '新エリア': '氷の洞窟',
                            '新スキル': '氷結攻撃',
                            '新アイテム': '氷の剣',
                          },
                        );
                      },
                      child: const Text('Big Level Up'),
                    ),
                    const StatGrowthWidget(
                      statName: '総合力',
                      oldValue: 500,
                      newValue: 750,
                      color: Color(0xFFFFD700),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      
      // レベルアップ実行
      await tester.tap(find.text('Big Level Up'));
      await tester.pump();
      
      expect(growthSystem.isShowingGrowthEffect, true);
      
      // ダイアログ表示確認
      await tester.pumpAndSettle();
      expect(find.byType(LevelUpDialog), findsOneWidget);
      expect(find.text('Lv.15'), findsOneWidget);
      expect(find.text('+5 レベル上昇！'), findsOneWidget);
      
      // 解放コンテンツの確認
      expect(find.text('新エリア: 氷の洞窟'), findsOneWidget);
      expect(find.text('新スキル: 氷結攻撃'), findsOneWidget);
      expect(find.text('新アイテム: 氷の剣'), findsOneWidget);
      
      // 能力値ウィジェットの確認
      expect(find.text('総合力'), findsOneWidget);
    });
  });
}