import 'package:flutter/material.dart';
import 'premium_animations.dart';
import 'chain_animation.dart';
import 'premium_theme.dart';

/// アニメーション制御システム
class PremiumAnimationController {
  static final Map<String, GlobalKey> _animationKeys = {};
  static final Map<String, VoidCallback> _animationCallbacks = {};

  /// アニメーションキーを登録
  static void registerAnimation(String id, GlobalKey key, VoidCallback? callback) {
    _animationKeys[id] = key;
    if (callback != null) {
      _animationCallbacks[id] = callback;
    }
  }

  /// アニメーションを開始
  static void startAnimation(String id) {
    final callback = _animationCallbacks[id];
    callback?.call();
  }

  /// 全てのアニメーションをリセット
  static void resetAllAnimations() {
    _animationCallbacks.clear();
    _animationKeys.clear();
  }
}

/// 統合アニメーションウィジェット
class PremiumAnimatedWidget extends StatefulWidget {
  final Widget child;
  final String? animationId;
  final PremiumAnimationType type;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final bool autoStart;
  final VoidCallback? onComplete;
  final Map<String, dynamic>? customParams;

  const PremiumAnimatedWidget({
    Key? key,
    required this.child,
    this.animationId,
    required this.type,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.autoStart = true,
    this.onComplete,
    this.customParams,
  }) : super(key: key);

  @override
  State<PremiumAnimatedWidget> createState() => _PremiumAnimatedWidgetState();
}

class _PremiumAnimatedWidgetState extends State<PremiumAnimatedWidget> {
  final GlobalKey _animationKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.animationId != null) {
      PremiumAnimationController.registerAnimation(
        widget.animationId!,
        _animationKey,
        _startAnimation,
      );
    }
  }

  void _startAnimation() {
    // アニメーション開始ロジック
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.type) {
      case PremiumAnimationType.slideIn:
        return SlideInAnimation(
          key: _animationKey,
          duration: widget.duration,
          delay: widget.delay,
          curve: widget.curve,
          autoStart: widget.autoStart,
          begin: widget.customParams?['begin'] ?? const Offset(0, 1),
          end: widget.customParams?['end'] ?? Offset.zero,
          child: widget.child,
        );
      
      case PremiumAnimationType.scale:
        return ScaleAnimation(
          key: _animationKey,
          duration: widget.duration,
          delay: widget.delay,
          curve: widget.curve,
          autoStart: widget.autoStart,
          begin: widget.customParams?['begin'] ?? 0.0,
          end: widget.customParams?['end'] ?? 1.0,
          alignment: widget.customParams?['alignment'] ?? Alignment.center,
          child: widget.child,
        );
      
      case PremiumAnimationType.rotate:
        return RotateAnimation(
          key: _animationKey,
          duration: widget.duration,
          delay: widget.delay,
          curve: widget.curve,
          autoStart: widget.autoStart,
          begin: widget.customParams?['begin'] ?? 0.0,
          end: widget.customParams?['end'] ?? 1.0,
          alignment: widget.customParams?['alignment'] ?? Alignment.center,
          child: widget.child,
        );
      
      case PremiumAnimationType.morph:
        return MorphAnimation(
          key: _animationKey,
          duration: widget.duration,
          delay: widget.delay,
          curve: widget.curve,
          autoStart: widget.autoStart,
          beginBorderRadius: widget.customParams?['beginBorderRadius'],
          endBorderRadius: widget.customParams?['endBorderRadius'],
          beginColor: widget.customParams?['beginColor'],
          endColor: widget.customParams?['endColor'],
          beginWidth: widget.customParams?['beginWidth'],
          endWidth: widget.customParams?['endWidth'],
          beginHeight: widget.customParams?['beginHeight'],
          endHeight: widget.customParams?['endHeight'],
          child: widget.child,
        );
      
      case PremiumAnimationType.chain:
        final steps = widget.customParams?['steps'] as List<ChainAnimationStep>? 
            ?? PremiumChainAnimations.elegantEntrance;
        return ChainAnimation(
          key: _animationKey,
          steps: steps,
          autoStart: widget.autoStart,
          repeat: widget.customParams?['repeat'] ?? false,
          onComplete: widget.onComplete,
          child: widget.child,
        );
    }
  }
}

/// アニメーションタイプ列挙型
enum PremiumAnimationType {
  slideIn,
  scale,
  rotate,
  morph,
  chain,
}

/// プリセットアニメーション用のヘルパーウィジェット
class PremiumPresetAnimation extends StatelessWidget {
  final Widget child;
  final PremiumAnimationPreset preset;
  final Duration? duration;
  final Duration? delay;
  final bool autoStart;
  final VoidCallback? onComplete;

  const PremiumPresetAnimation({
    Key? key,
    required this.child,
    required this.preset,
    this.duration,
    this.delay,
    this.autoStart = true,
    this.onComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (preset) {
      case PremiumAnimationPreset.elegantEntrance:
        return ChainAnimation(
          steps: PremiumChainAnimations.elegantEntrance,
          autoStart: autoStart,
          onComplete: onComplete,
          child: child,
        );
      
      case PremiumAnimationPreset.dramaticEntrance:
        return ChainAnimation(
          steps: PremiumChainAnimations.dramaticEntrance,
          autoStart: autoStart,
          onComplete: onComplete,
          child: child,
        );
      
      case PremiumAnimationPreset.bounceEntrance:
        return ChainAnimation(
          steps: PremiumChainAnimations.bounceEntrance,
          autoStart: autoStart,
          onComplete: onComplete,
          child: child,
        );
      
      case PremiumAnimationPreset.spinFadeIn:
        return ChainAnimation(
          steps: PremiumChainAnimations.spinFadeIn,
          autoStart: autoStart,
          onComplete: onComplete,
          child: child,
        );
      
      case PremiumAnimationPreset.celebration:
        return ChainAnimation(
          steps: PremiumChainAnimations.celebrationAnimation,
          autoStart: autoStart,
          onComplete: onComplete,
          child: child,
        );
      
      case PremiumAnimationPreset.slideFromLeft:
        return SlideInAnimation(
          begin: const Offset(-1, 0),
          end: Offset.zero,
          duration: duration ?? PremiumEffects.normalAnimation,
          delay: delay ?? Duration.zero,
          curve: PremiumEasing.backOut,
          autoStart: autoStart,
          child: child,
        );
      
      case PremiumAnimationPreset.slideFromRight:
        return SlideInAnimation(
          begin: const Offset(1, 0),
          end: Offset.zero,
          duration: duration ?? PremiumEffects.normalAnimation,
          delay: delay ?? Duration.zero,
          curve: PremiumEasing.backOut,
          autoStart: autoStart,
          child: child,
        );
      
      case PremiumAnimationPreset.slideFromTop:
        return SlideInAnimation(
          begin: const Offset(0, -1),
          end: Offset.zero,
          duration: duration ?? PremiumEffects.normalAnimation,
          delay: delay ?? Duration.zero,
          curve: PremiumEasing.bounceOut,
          autoStart: autoStart,
          child: child,
        );
      
      case PremiumAnimationPreset.slideFromBottom:
        return SlideInAnimation(
          begin: const Offset(0, 1),
          end: Offset.zero,
          duration: duration ?? PremiumEffects.normalAnimation,
          delay: delay ?? Duration.zero,
          curve: PremiumEasing.backOut,
          autoStart: autoStart,
          child: child,
        );
      
      case PremiumAnimationPreset.scaleUp:
        return ScaleAnimation(
          begin: 0.0,
          end: 1.0,
          duration: duration ?? PremiumEffects.normalAnimation,
          delay: delay ?? Duration.zero,
          curve: PremiumEasing.elasticOut,
          autoStart: autoStart,
          child: child,
        );
      
      case PremiumAnimationPreset.scaleDown:
        return ScaleAnimation(
          begin: 1.5,
          end: 1.0,
          duration: duration ?? PremiumEffects.normalAnimation,
          delay: delay ?? Duration.zero,
          curve: PremiumEasing.backOut,
          autoStart: autoStart,
          child: child,
        );
    }
  }
}

/// プリセットアニメーション列挙型
enum PremiumAnimationPreset {
  elegantEntrance,
  dramaticEntrance,
  bounceEntrance,
  spinFadeIn,
  celebration,
  slideFromLeft,
  slideFromRight,
  slideFromTop,
  slideFromBottom,
  scaleUp,
  scaleDown,
}

/// アニメーション用のヘルパー関数
class PremiumAnimationHelpers {
  /// 遅延付きアニメーション実行
  static Future<void> delayedAnimation(
    Duration delay,
    VoidCallback animation,
  ) async {
    await Future.delayed(delay);
    animation();
  }

  /// 順次アニメーション実行
  static Future<void> sequentialAnimations(
    List<VoidCallback> animations,
    Duration interval,
  ) async {
    for (final animation in animations) {
      animation();
      await Future.delayed(interval);
    }
  }

  /// 並列アニメーション実行
  static void parallelAnimations(List<VoidCallback> animations) {
    for (final animation in animations) {
      animation();
    }
  }

  /// カスタムイージング関数作成
  static Curve createCustomEasing(
    double x1, double y1, double x2, double y2,
  ) {
    return Cubic(x1, y1, x2, y2);
  }
}