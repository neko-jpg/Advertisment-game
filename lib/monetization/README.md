# UX配慮型収益化システム (UX-Considerate Monetization System)

このシステムは、Google Play Storeセルラン上位を目指すための包括的な収益化システムです。ユーザー体験を最優先に考慮しながら、効果的な収益化を実現します。

## 実装された要件

### 要件2.1-2.7: UX配慮型収益化システム
- ✅ 2.1: 自然なタイミングでの広告表示（ゲームオーバー、達成時）
- ✅ 2.2: 広告価値の事前説明機能（「広告を見てコンティニュー」）
- ✅ 2.3: 広告視聴後の感謝・フォローアップシステム
- ✅ 2.4: 広告表示タイミングの最適化アルゴリズム
- ✅ 2.5: 4段階価格設定（120円、250円、480円、980円）
- ✅ 2.6: VIPパス（月額480円）サブスクリプション機能
- ✅ 2.7: 広告疲れ検知と頻度自動調整機能

## システム構成

### 1. MonetizationOrchestrator
**役割**: 収益化戦略の統合管理
- 広告疲れレベルに基づく頻度調整
- ユーザー価値に基づく広告配置
- 段階的課金オファーの生成
- 代替収益化手段の提案

**主要機能**:
```dart
// 広告疲れに基づく頻度調整
await orchestrator.adjustAdFrequency(userId, adHistory);

// 価値提案型広告表示判定
bool shouldShow = await orchestrator.shouldShowValuePropositionAd(context);

// 段階的オファー生成
List<IAPOffer> offers = orchestrator.generateTieredOffers(profile);
```

### 2. AdExperienceManager
**役割**: 自然な広告体験の管理
- 自然なタイミングでの広告表示判定
- 広告価値の事前説明生成
- 広告後の感謝とフォローアップ

**主要機能**:
```dart
// 自然なタイミング判定
bool isNatural = manager.isNaturalAdMoment(gameState, session);

// 価値提案メッセージ生成
String proposition = manager.generateAdValueProposition(adType, context);

// 広告後体験処理
await manager.handlePostAdExperience(result);
```

### 3. TieredPricingSystem
**役割**: 段階的価格設定とサブスクリプション管理
- 購入意向検知
- 4段階価格設定（120/250/480/980円）
- VIPパス（月額480円）最適化

**価格設定**:
- **スターターパック**: 120円 - 100コイン
- **バリューパック**: 250円 - 250コイン + 5ジェム（25%ボーナス）
- **プレミアムパック**: 480円 - 600コイン + 15ジェム（50%ボーナス）
- **メガパック**: 980円 - 1400コイン + 40ジェム（75%ボーナス）

### 4. BillingSystem
**役割**: Google Play Billing統合
- アプリ内課金処理
- プレミアム通貨管理
- VIPステータス管理
- 購入履歴追跡

### 5. MultiNetworkAdSystem
**役割**: 複数広告ネットワーク統合
- AdMob、Unity Ads、IronSource統合
- eCPM最適化エンジン
- フォールバック機能
- 地域別配信最適化

## 広告疲れレベルと対応

### AdFatigueLevel
- **none**: 1日5回未満、スキップ率20%未満
- **low**: 1日5-9回、スキップ率20-40%
- **medium**: 1日10-14回、スキップ率40-60%
- **high**: 1日15-19回、スキップ率60-80%
- **critical**: 1日20回以上、スキップ率80%以上

### 疲れレベル別対応
```dart
static const Map<AdFatigueLevel, int> _maxDailyAds = {
  AdFatigueLevel.none: 25,
  AdFatigueLevel.low: 20,
  AdFatigueLevel.medium: 15,
  AdFatigueLevel.high: 8,
  AdFatigueLevel.critical: 3,
};
```

## 使用方法

### 1. 初期化
```dart
final monetization = MonetizationIntegration(logger: logger);
await monetization.initialize();
```

### 2. 最適な広告表示
```dart
final success = await monetization.showOptimalAd(
  userId: userId,
  gameContext: gameContext,
  userSession: userSession,
  placement: 'game_over',
);
```

### 3. 購入オファー表示
```dart
final presentation = await monetization.presentOptimalPurchaseOffer(
  userId: userId,
  gameContext: gameContext,
  behaviorData: behaviorData,
);
```

### 4. VIPオファー作成
```dart
final vipOffer = await monetization.presentVIPOffer(
  userId: userId,
  customDiscount: 20.0,
);
```

## データモデル

### MonetizationData
ユーザーの包括的な収益化データ
- 広告インタラクション履歴
- 支出プロファイル
- サブスクリプション状況
- 生涯価値（LTV）

### GameContext
広告表示判定のためのゲーム状況
- 現在スコア
- セッション時間
- プレイヤー気分
- 連続失敗回数

## テスト

システムの動作確認:
```bash
flutter test test/monetization/simple_monetization_test.dart
```

## 設計原則

1. **UXファースト**: ユーザー体験を損なわない収益化
2. **データドリブン**: 行動分析に基づく最適化
3. **段階的アプローチ**: 強制感のない自然な課金導線
4. **透明性**: 広告価値の事前説明
5. **感謝の表現**: 広告視聴後のフォローアップ

## パフォーマンス指標

- **広告疲れ率**: 20%以下を維持
- **課金転換率**: セグメント別最適化
- **セッション継続率**: 広告後90%以上
- **ユーザー満足度**: 4.0以上維持

## 今後の拡張

- A/Bテスト機能の強化
- 機械学習による予測精度向上
- リアルタイム最適化
- 競合分析機能
- 季節イベント対応

このシステムにより、ユーザー体験を重視しながら効果的な収益化を実現し、Google Play Storeセルラン上位進出を目指します。