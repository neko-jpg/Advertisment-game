要件定義書（改訂版）：QuickDrawDash を“面白くする”ための仕様

本要件は、提供レポートの戦略（PCG+DDA、メタゲーム、ハイブリッドマネタイズ、ゲームジュース、物語断章）を現在のコード基盤に統合するための実装仕様です。
 

QuickDrawDashを面白くするための改善提案

0. 目標（KPI）

Retention: D1 ≥ 35%, D7 ≥ 15%, D30 ≥ 5%。

Engagement: 平均セッション ≥ 6分、日次セッション数 ≥ 3。

Monetization: ARPDAU ≥ $0.06、Rewarded視聴率 ≥ 35%。 

QuickDrawDash 改善リサーチ計画

1. コアゲームループ要件

操作（片手完結）

画面タップ＝ジャンプ、プレス&ドラッグ＝線を描く。誤判定防止閾値を適用。

受け入れ基準：チュートリアルなしで30秒以内に基本行動が可能（ユーザテストN=5）。

QuickDrawDashを面白くするための改善提案

描画とリソース

インクメーターを導入。描画で消費・アイテム/チェックポイントで補充。

線の種類（弾む/高速/粘着 等）をアンロック式で提供。

受け入れ基準：インク枯渇で意思決定が生まれ、連続橋架けが不利になる。

QuickDrawDash 改善リサーチ計画

物理

線は厚み・法線を持ち、傾斜で滑走、摩擦値は線種で可変。

受け入れ基準：5°刻みの斜面で速度差が体感できる。

QuickDrawDash 改善リサーチ計画

2. コンテンツ生成（PCG）＆難易度（DDA）

チャンク制PCG

入口/出口規格化済みの**プレハブ（チャンク）**を連結。環境テーマ別のプールを用意。

受け入れ基準：連結時に不自然な段差・詰みが発生しない。

QuickDrawDash 改善リサーチ計画

DDA

指標：生存時間/ニアミス/インク効率/収集率などを加重評価し速度・敵密度・補充率を調整。

階段状ペーシング（緊張→小休止）を適用。

受け入れ基準：上級者は2分で心地よく圧、初心者は30秒で学習達成。

QuickDrawDash 改善リサーチ計画

3. 敵＆障害デザイン（“キモカワ”）

初期3種：ホッパー（ジャンプ誘発）、フローター（回避描画）、スピッター（防壁描画）。

受け入れ基準：各敵が異なる描画アクションを誘発し、被りが無い。

QuickDrawDash 改善リサーチ計画

4. 物語・演出（ゲームジュース）

断章ストーリー：セーブポイント到達で短いパネル解放。

演出：カメラ揺れ/ズーム、着地土埃、描画スウッシュ、危機スロー、表情差分。

受け入れ基準：ユーザ評価で「手触りが気持ちいい」が70%超。

QuickDrawDash 改善リサーチ計画

 

QuickDrawDashを面白くするための改善提案

5. メタゲーム

XPレベル、キャラアンロック（パッシブ付与）、コスメ（線の軌跡/スキン）。

デイリー/ウィークリーミッション、ログインカレンダー、イベント。

受け入れ基準：1週間で継続目標が常に1つ以上可視化。

QuickDrawDash 改善リサーチ計画

 

QuickDrawDashを面白くするための改善提案

6. マネタイズ（ハイブリッド）

Rewarded：死亡時復活、報酬倍増、デイリーミッション更新。

IAP：コスメ/キャラ/通貨パック、インタースティシャル削除（Rewardedは残す）。

頻度制御：AdFrequencyController + Remote Config。

受け入れ基準：広告起因離脱率の上昇なしかつ ARPDAU 達成。

QuickDrawDash 改善リサーチ計画

7. 技術要件（実装指針）

タイムステップ：物理は固定、dt クランプ導入。

プール：パーティクル/チャンク/プラットフォーム再利用。

入力：タップ/ドラッグ閾値、マルチタッチ干渉回避。

計測：イベント命名規約・バージョン付与・サンプリング。

AB基盤：Remote Config キー（dda.density, rewarded.revives.enabled 等）を一覧管理。

端末性能適応：Battery Optimizerでエフェクト密度を自動調整。

テスト：PCGチャンクの接続プロパティ単体テスト、DDA境界条件のゴールデンテスト。

8. 計測仕様（抜粋）

game_start: session_id, revives_unlocked, ink_multiplier, missions_available

game_end: score, duration, revives_used, coins_gained, near_misses, ink_efficiency

ad_show: trigger, policy_blocked_flags, elapsed_since_last

mission_complete: mission_id, type, reward
（イベントキーは定数クラスで集中管理／スキーマはNotion等にドキュメント化）

9. フェーズ別ロードマップ（8〜12週）

Phase 1（2–3週）: 物理クランプ/入力閾値/インクメーター/初期PCGチャンク3種 + 敵1種/ジュース基礎

Phase 2（3–4週）: DDA稼働、敵3種揃える、環境テーマ2種、ミッション＆ログボ

Phase 3（2–3週）: Rewarded&IAP実装、A/B、粒度の高いAnalytics、最終チューニング
（詳細マイルストーンはレポートの優先順位と一致）

QuickDrawDash 改善リサーチ計画

「改善案 → 実装タスク」対応表（抜粋）

インク制 → InkMeter モデル／UI／LinePlatformFactory のコスト勘定

線の性質 → InkType enum（friction/bounce/boost）と PhysicsMaterial 反映

PCGチャンク → ChunkPrefab + ChunkSpawner、接続I/F（入口Y/出口Y）

DDA → 既存 DifficultyAdjustmentEngine に重み学習/RCパラメータ注入

敵3種 → Hopper/Floater/Spitter コンポーネント、出現テーブルをDDA連動

ジュース → CameraEffects（揺れ/ズーム）、ParticleManager（着地/破壊/描画）、SoundController（描画/危機/成功）

メタ → PlayerWallet 連携の XP/ミッション/カレンダー、UIカード

広告 → FrequencyPoliciesをトリガー別に複合、ad_request_context を標準化
