/// プレミアムUI基盤システム
/// 
/// このライブラリは、プレミアムゲーム体験のためのUI基盤システムを提供します。
/// グラスモーフィズム効果、滑らかなアニメーション、動的グラデーション背景を含みます。
/// 
/// 主な機能:
/// - グラスモーフィズムウィジェット（半透明背景、ブラー効果、グロー効果）
/// - プレミアムアニメーションシステム（SlideIn、Scale、Rotate、Morph）
/// - チェーンアニメーション機能
/// - カスタムイージング関数とタイミング制御
/// - 統合されたテーマシステム
/// 
/// 使用例:
/// ```dart
/// import 'package:your_app/game/ui/premium/premium_ui.dart';
/// 
/// // グラスモーフィズムボタン
/// GlassmorphicButton(
///   onPressed: () {},
///   child: Text('Premium Button'),
/// )
/// 
/// // プリセットアニメーション
/// PremiumPresetAnimation(
///   preset: PremiumAnimationPreset.elegantEntrance,
///   child: YourWidget(),
/// )
/// 
/// // チェーンアニメーション
/// ChainAnimation(
///   steps: PremiumChainAnimations.dramaticEntrance,
///   child: YourWidget(),
/// )
/// ```

library premium_ui;

// Core theme and styling
export 'premium_theme.dart';

// Glassmorphic components
export 'glassmorphic_widget.dart';
export 'glassmorphic_components.dart';

// Animation system
export 'premium_animations.dart';
export 'chain_animation.dart';
export 'animation_controller_system.dart';

// Integration example
export 'premium_ui_integration_example.dart';