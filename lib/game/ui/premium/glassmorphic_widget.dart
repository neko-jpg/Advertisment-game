import 'dart:ui';
import 'package:flutter/material.dart';

/// プレミアムなグラスモーフィズム効果を提供するウィジェット
/// 半透明背景、ブラー効果、境界線グロー、シャドウ効果を実装
class GlassmorphicWidget extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color borderColor;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? shadows;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double glowIntensity;
  final Color glowColor;

  const GlassmorphicWidget({
    Key? key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.1,
    this.borderColor = const Color(0xFF00D4FF),
    this.borderWidth = 1.0,
    this.borderRadius,
    this.shadows,
    this.padding,
    this.margin,
    this.glowIntensity = 0.5,
    this.glowColor = const Color(0xFF00D4FF),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        boxShadow: [
          // 外側のグロー効果
          BoxShadow(
            color: glowColor.withOpacity(glowIntensity * 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          // 内側のシャドウ効果
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          // カスタムシャドウ
          if (shadows != null) ...shadows!,
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(opacity),
              borderRadius: borderRadius ?? BorderRadius.circular(16),
              border: Border.all(
                color: borderColor.withOpacity(0.8),
                width: borderWidth,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(opacity * 1.5),
                  Colors.white.withOpacity(opacity * 0.5),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// プレミアムボタン用のグラスモーフィズムウィジェット
class GlassmorphicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double blur;
  final double opacity;
  final Color borderColor;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double glowIntensity;
  final Color glowColor;
  final Duration animationDuration;

  const GlassmorphicButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.blur = 10.0,
    this.opacity = 0.15,
    this.borderColor = const Color(0xFF00D4FF),
    this.borderWidth = 1.0,
    this.borderRadius,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.glowIntensity = 0.5,
    this.glowColor = const Color(0xFF00D4FF),
    this.animationDuration = const Duration(milliseconds: 200),
  }) : super(key: key);

  @override
  State<GlassmorphicButton> createState() => _GlassmorphicButtonState();
}

class _GlassmorphicButtonState extends State<GlassmorphicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: widget.glowIntensity,
      end: widget.glowIntensity * 1.5,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null ? _handleTapDown : null,
      onTapUp: widget.onPressed != null ? _handleTapUp : null,
      onTapCancel: widget.onPressed != null ? _handleTapCancel : null,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GlassmorphicWidget(
              blur: widget.blur,
              opacity: widget.opacity,
              borderColor: widget.borderColor,
              borderWidth: widget.borderWidth,
              borderRadius: widget.borderRadius,
              padding: widget.padding,
              glowIntensity: _glowAnimation.value,
              glowColor: widget.glowColor,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

/// プレミアムカード用のグラスモーフィズムウィジェット
class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color borderColor;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double glowIntensity;
  final Color glowColor;
  final bool showReflection;

  const GlassmorphicCard({
    Key? key,
    required this.child,
    this.blur = 15.0,
    this.opacity = 0.08,
    this.borderColor = const Color(0xFF9D4EDD),
    this.borderWidth = 1.0,
    this.borderRadius,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.glowIntensity = 0.3,
    this.glowColor = const Color(0xFF9D4EDD),
    this.showReflection = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        boxShadow: [
          // メインのグロー効果
          BoxShadow(
            color: glowColor.withOpacity(glowIntensity * 0.4),
            blurRadius: 25,
            spreadRadius: 3,
          ),
          // 深度のあるシャドウ
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: borderRadius ?? BorderRadius.circular(20),
              border: Border.all(
                color: borderColor.withOpacity(0.6),
                width: borderWidth,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(opacity * 2),
                  Colors.white.withOpacity(opacity * 0.3),
                  if (showReflection) Colors.white.withOpacity(opacity * 1.5),
                ],
                stops: showReflection ? [0.0, 0.5, 1.0] : [0.0, 1.0],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}