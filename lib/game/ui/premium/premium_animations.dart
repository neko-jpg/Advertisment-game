import 'package:flutter/material.dart';
import 'premium_theme.dart';

/// プレミアムアニメーション用のカスタムイージング関数
class PremiumEasing {
  static const Curve elasticOut = Curves.elasticOut;
  static const Curve bounceOut = Curves.bounceOut;
  static const Curve backOut = Cubic(0.175, 0.885, 0.32, 1.275);
  static const Curve smoothStep = Cubic(0.4, 0.0, 0.2, 1.0);
  static const Curve dramatic = Cubic(0.25, 0.46, 0.45, 0.94);
  static const Curve gentle = Cubic(0.25, 0.1, 0.25, 1.0);
}

/// SlideInアニメーション
class SlideInAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset begin;
  final Offset end;
  final Curve curve;
  final bool autoStart;

  const SlideInAnimation({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
    this.begin = const Offset(0, 1),
    this.end = Offset.zero,
    this.curve = PremiumEasing.backOut,
    this.autoStart = true,
  }) : super(key: key);

  @override
  State<SlideInAnimation> createState() => _SlideInAnimationState();
}

class _SlideInAnimationState extends State<SlideInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    
    _slideAnimation = Tween<Offset>(
      begin: widget.begin,
      end: widget.end,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    if (widget.autoStart) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void start() => _controller.forward();
  void reverse() => _controller.reverse();
  void reset() => _controller.reset();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Scaleアニメーション
class ScaleAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double begin;
  final double end;
  final Curve curve;
  final bool autoStart;
  final Alignment alignment;

  const ScaleAnimation({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.delay = Duration.zero,
    this.begin = 0.0,
    this.end = 1.0,
    this.curve = PremiumEasing.elasticOut,
    this.autoStart = true,
    this.alignment = Alignment.center,
  }) : super(key: key);

  @override
  State<ScaleAnimation> createState() => _ScaleAnimationState();
}

class _ScaleAnimationState extends State<ScaleAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    
    _scaleAnimation = Tween<double>(
      begin: widget.begin,
      end: widget.end,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    if (widget.autoStart) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void start() => _controller.forward();
  void reverse() => _controller.reverse();
  void reset() => _controller.reset();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          alignment: widget.alignment,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Rotateアニメーション
class RotateAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double begin;
  final double end;
  final Curve curve;
  final bool autoStart;
  final Alignment alignment;

  const RotateAnimation({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 800),
    this.delay = Duration.zero,
    this.begin = 0.0,
    this.end = 1.0,
    this.curve = PremiumEasing.smoothStep,
    this.autoStart = true,
    this.alignment = Alignment.center,
  }) : super(key: key);

  @override
  State<RotateAnimation> createState() => _RotateAnimationState();
}

class _RotateAnimationState extends State<RotateAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotateAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    
    _rotateAnimation = Tween<double>(
      begin: widget.begin,
      end: widget.end,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    if (widget.autoStart) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void start() => _controller.forward();
  void reverse() => _controller.reverse();
  void reset() => _controller.reset();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotateAnimation.value * 2 * 3.14159,
          alignment: widget.alignment,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Morphアニメーション（形状変化）
class MorphAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final BorderRadius? beginBorderRadius;
  final BorderRadius? endBorderRadius;
  final Color? beginColor;
  final Color? endColor;
  final double? beginWidth;
  final double? endWidth;
  final double? beginHeight;
  final double? endHeight;
  final Curve curve;
  final bool autoStart;

  const MorphAnimation({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.beginBorderRadius,
    this.endBorderRadius,
    this.beginColor,
    this.endColor,
    this.beginWidth,
    this.endWidth,
    this.beginHeight,
    this.endHeight,
    this.curve = PremiumEasing.dramatic,
    this.autoStart = true,
  }) : super(key: key);

  @override
  State<MorphAnimation> createState() => _MorphAnimationState();
}

class _MorphAnimationState extends State<MorphAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<BorderRadius?> _borderRadiusAnimation;
  late Animation<Color?> _colorAnimation;
  late Animation<double?> _widthAnimation;
  late Animation<double?> _heightAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    
    if (widget.beginBorderRadius != null && widget.endBorderRadius != null) {
      _borderRadiusAnimation = BorderRadiusTween(
        begin: widget.beginBorderRadius,
        end: widget.endBorderRadius,
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    }
    
    if (widget.beginColor != null && widget.endColor != null) {
      _colorAnimation = ColorTween(
        begin: widget.beginColor,
        end: widget.endColor,
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    }
    
    if (widget.beginWidth != null && widget.endWidth != null) {
      _widthAnimation = Tween<double>(
        begin: widget.beginWidth,
        end: widget.endWidth,
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    }
    
    if (widget.beginHeight != null && widget.endHeight != null) {
      _heightAnimation = Tween<double>(
        begin: widget.beginHeight,
        end: widget.endHeight,
      ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    }

    if (widget.autoStart) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void start() => _controller.forward();
  void reverse() => _controller.reverse();
  void reset() => _controller.reset();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: _widthAnimation?.value,
          height: _heightAnimation?.value,
          decoration: BoxDecoration(
            borderRadius: _borderRadiusAnimation?.value,
            color: _colorAnimation?.value,
          ),
          child: widget.child,
        );
      },
    );
  }
}