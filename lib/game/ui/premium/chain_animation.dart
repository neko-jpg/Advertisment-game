import 'package:flutter/material.dart';
import 'premium_theme.dart';

/// チェーンアニメーション用のアニメーション定義
abstract class ChainAnimationStep {
  Duration get duration;
  Duration get delay;
  Widget animate(Widget child, AnimationController controller);
}

/// スライドアニメーションステップ
class SlideStep implements ChainAnimationStep {
  @override
  final Duration duration;
  @override
  final Duration delay;
  final Offset begin;
  final Offset end;
  final Curve curve;

  const SlideStep({
    required this.duration,
    this.delay = Duration.zero,
    required this.begin,
    required this.end,
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget animate(Widget child, AnimationController controller) {
    final animation = Tween<Offset>(begin: begin, end: end)
        .animate(CurvedAnimation(parent: controller, curve: curve));
    
    return SlideTransition(position: animation, child: child);
  }
}

/// スケールアニメーションステップ
class ScaleStep implements ChainAnimationStep {
  @override
  final Duration duration;
  @override
  final Duration delay;
  final double begin;
  final double end;
  final Curve curve;
  final Alignment alignment;

  const ScaleStep({
    required this.duration,
    this.delay = Duration.zero,
    required this.begin,
    required this.end,
    this.curve = Curves.elasticOut,
    this.alignment = Alignment.center,
  });

  @override
  Widget animate(Widget child, AnimationController controller) {
    final animation = Tween<double>(begin: begin, end: end)
        .animate(CurvedAnimation(parent: controller, curve: curve));
    
    return ScaleTransition(
      scale: animation,
      alignment: alignment,
      child: child,
    );
  }
}

/// 回転アニメーションステップ
class RotateStep implements ChainAnimationStep {
  @override
  final Duration duration;
  @override
  final Duration delay;
  final double begin;
  final double end;
  final Curve curve;
  final Alignment alignment;

  const RotateStep({
    required this.duration,
    this.delay = Duration.zero,
    required this.begin,
    required this.end,
    this.curve = Curves.easeInOut,
    this.alignment = Alignment.center,
  });

  @override
  Widget animate(Widget child, AnimationController controller) {
    final animation = Tween<double>(begin: begin, end: end)
        .animate(CurvedAnimation(parent: controller, curve: curve));
    
    return RotationTransition(
      turns: animation,
      alignment: alignment,
      child: child,
    );
  }
}

/// フェードアニメーションステップ
class FadeStep implements ChainAnimationStep {
  @override
  final Duration duration;
  @override
  final Duration delay;
  final double begin;
  final double end;
  final Curve curve;

  const FadeStep({
    required this.duration,
    this.delay = Duration.zero,
    required this.begin,
    required this.end,
    this.curve = Curves.easeInOut,
  });

  @override
  Widget animate(Widget child, AnimationController controller) {
    final animation = Tween<double>(begin: begin, end: end)
        .animate(CurvedAnimation(parent: controller, curve: curve));
    
    return FadeTransition(opacity: animation, child: child);
  }
}

/// カスタムアニメーションステップ
class CustomStep implements ChainAnimationStep {
  @override
  final Duration duration;
  @override
  final Duration delay;
  final Widget Function(Widget child, AnimationController controller) builder;

  const CustomStep({
    required this.duration,
    this.delay = Duration.zero,
    required this.builder,
  });

  @override
  Widget animate(Widget child, AnimationController controller) {
    return builder(child, controller);
  }
}

/// チェーンアニメーションシステム
class ChainAnimation extends StatefulWidget {
  final Widget child;
  final List<ChainAnimationStep> steps;
  final bool autoStart;
  final bool repeat;
  final VoidCallback? onComplete;
  final Duration? totalDuration;

  const ChainAnimation({
    Key? key,
    required this.child,
    required this.steps,
    this.autoStart = true,
    this.repeat = false,
    this.onComplete,
    this.totalDuration,
  }) : super(key: key);

  @override
  State<ChainAnimation> createState() => _ChainAnimationState();
}

class _ChainAnimationState extends State<ChainAnimation>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  int _currentStep = 0;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        start();
      });
    }
  }

  void _initializeControllers() {
    _controllers = widget.steps.map((step) {
      return AnimationController(
        duration: step.duration,
        vsync: this,
      );
    }).toList();

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(controller);
    }).toList();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> start() async {
    if (_isRunning) return;
    
    _isRunning = true;
    _currentStep = 0;

    do {
      for (int i = 0; i < widget.steps.length; i++) {
        _currentStep = i;
        
        // 遅延があれば待機
        if (widget.steps[i].delay > Duration.zero) {
          await Future.delayed(widget.steps[i].delay);
        }
        
        // アニメーション実行
        await _controllers[i].forward();
        
        if (!mounted) return;
      }
      
      if (widget.repeat) {
        // リピートの場合は全てリセット
        for (final controller in _controllers) {
          controller.reset();
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } while (widget.repeat && mounted);

    _isRunning = false;
    widget.onComplete?.call();
  }

  Future<void> reverse() async {
    if (!_isRunning) return;
    
    for (int i = _controllers.length - 1; i >= 0; i--) {
      await _controllers[i].reverse();
      if (!mounted) return;
    }
    
    _isRunning = false;
  }

  void reset() {
    for (final controller in _controllers) {
      controller.reset();
    }
    _currentStep = 0;
    _isRunning = false;
  }

  void stop() {
    for (final controller in _controllers) {
      controller.stop();
    }
    _isRunning = false;
  }

  @override
  Widget build(BuildContext context) {
    Widget result = widget.child;
    
    // 各ステップのアニメーションを順番に適用
    for (int i = 0; i < widget.steps.length; i++) {
      result = widget.steps[i].animate(result, _controllers[i]);
    }
    
    return result;
  }
}

/// プリセットのチェーンアニメーション
class PremiumChainAnimations {
  /// エレガントな登場アニメーション
  static List<ChainAnimationStep> get elegantEntrance => [
    const FadeStep(
      duration: Duration(milliseconds: 200),
      begin: 0.0,
      end: 1.0,
      curve: Curves.easeIn,
    ),
    const SlideStep(
      duration: Duration(milliseconds: 400),
      delay: Duration(milliseconds: 100),
      begin: Offset(0, 0.5),
      end: Offset.zero,
      curve: Curves.easeOutCubic,
    ),
    const ScaleStep(
      duration: Duration(milliseconds: 300),
      delay: Duration(milliseconds: 200),
      begin: 0.8,
      end: 1.0,
      curve: Curves.elasticOut,
    ),
  ];

  /// ドラマチックな登場アニメーション
  static List<ChainAnimationStep> get dramaticEntrance => [
    const ScaleStep(
      duration: Duration(milliseconds: 600),
      begin: 0.0,
      end: 1.2,
      curve: Curves.elasticOut,
    ),
    const ScaleStep(
      duration: Duration(milliseconds: 200),
      delay: Duration(milliseconds: 100),
      begin: 1.2,
      end: 1.0,
      curve: Curves.easeInOut,
    ),
    const RotateStep(
      duration: Duration(milliseconds: 400),
      delay: Duration(milliseconds: 50),
      begin: 0.0,
      end: 0.05,
      curve: Curves.easeInOut,
    ),
    const RotateStep(
      duration: Duration(milliseconds: 400),
      delay: Duration(milliseconds: 100),
      begin: 0.05,
      end: 0.0,
      curve: Curves.easeInOut,
    ),
  ];

  /// バウンス登場アニメーション
  static List<ChainAnimationStep> get bounceEntrance => [
    const SlideStep(
      duration: Duration(milliseconds: 500),
      begin: Offset(0, -1),
      end: Offset.zero,
      curve: Curves.bounceOut,
    ),
    const ScaleStep(
      duration: Duration(milliseconds: 300),
      delay: Duration(milliseconds: 200),
      begin: 1.0,
      end: 1.1,
      curve: Curves.elasticOut,
    ),
    const ScaleStep(
      duration: Duration(milliseconds: 200),
      delay: Duration(milliseconds: 100),
      begin: 1.1,
      end: 1.0,
      curve: Curves.easeInOut,
    ),
  ];

  /// 回転フェードイン
  static List<ChainAnimationStep> get spinFadeIn => [
    const FadeStep(
      duration: Duration(milliseconds: 300),
      begin: 0.0,
      end: 1.0,
      curve: Curves.easeIn,
    ),
    const RotateStep(
      duration: Duration(milliseconds: 800),
      begin: 0.0,
      end: 1.0,
      curve: Curves.easeOutCubic,
    ),
    const ScaleStep(
      duration: Duration(milliseconds: 400),
      delay: Duration(milliseconds: 200),
      begin: 0.5,
      end: 1.0,
      curve: Curves.elasticOut,
    ),
  ];

  /// 成功時の祝福アニメーション
  static List<ChainAnimationStep> get celebrationAnimation => [
    const ScaleStep(
      duration: Duration(milliseconds: 200),
      begin: 1.0,
      end: 1.3,
      curve: Curves.easeOut,
    ),
    const RotateStep(
      duration: Duration(milliseconds: 400),
      delay: Duration(milliseconds: 50),
      begin: 0.0,
      end: 0.1,
      curve: Curves.easeInOut,
    ),
    const RotateStep(
      duration: Duration(milliseconds: 400),
      delay: Duration(milliseconds: 100),
      begin: 0.1,
      end: -0.1,
      curve: Curves.easeInOut,
    ),
    const RotateStep(
      duration: Duration(milliseconds: 300),
      delay: Duration(milliseconds: 100),
      begin: -0.1,
      end: 0.0,
      curve: Curves.easeInOut,
    ),
    const ScaleStep(
      duration: Duration(milliseconds: 300),
      delay: Duration(milliseconds: 200),
      begin: 1.3,
      end: 1.0,
      curve: Curves.elasticOut,
    ),
  ];
}