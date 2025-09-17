import 'dart:ui';
import 'package:flutter/material.dart';
import 'glassmorphic_widget.dart';
import 'premium_theme.dart';

/// プレミアムなダイアログ用のグラスモーフィズムコンテナ
class GlassmorphicDialog extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final bool dismissible;
  final double maxWidth;
  final double maxHeight;

  const GlassmorphicDialog({
    Key? key,
    required this.child,
    this.title,
    this.actions,
    this.dismissible = true,
    this.maxWidth = 400,
    this.maxHeight = 600,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
        child: GlassmorphicCard(
          blur: 20,
          opacity: 0.1,
          borderColor: PremiumColors.primary,
          borderWidth: 1.5,
          glowIntensity: 0.6,
          glowColor: PremiumColors.primary,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title!,
                          style: PremiumTextStyles.subtitle,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (dismissible)
                        GlassmorphicButton(
                          onPressed: () => Navigator.of(context).pop(),
                          padding: const EdgeInsets.all(8),
                          borderRadius: BorderRadius.circular(12),
                          child: const Icon(
                            Icons.close,
                            color: PremiumColors.textSecondary,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        PremiumColors.borderLight,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ],
              Flexible(child: child),
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        PremiumColors.borderLight,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: actions!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// プレミアムなナビゲーションバー
class GlassmorphicNavigationBar extends StatelessWidget {
  final List<GlassmorphicNavigationItem> items;
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final double height;

  const GlassmorphicNavigationBar({
    Key? key,
    required this.items,
    required this.currentIndex,
    this.onTap,
    this.height = 80,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.all(16),
      child: GlassmorphicWidget(
        blur: 15,
        opacity: 0.12,
        borderColor: PremiumColors.borderMedium,
        borderRadius: BorderRadius.circular(25),
        glowIntensity: 0.4,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = index == currentIndex;
            
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap?.call(index),
                child: AnimatedContainer(
                  duration: PremiumEffects.normalAnimation,
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: isSelected 
                        ? PremiumColors.primary.withOpacity(0.2)
                        : Colors.transparent,
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: PremiumColors.primary.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ] : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: PremiumEffects.normalAnimation,
                        child: Icon(
                          item.icon,
                          color: isSelected 
                              ? PremiumColors.primary
                              : PremiumColors.textSecondary,
                          size: isSelected ? 28 : 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: PremiumEffects.normalAnimation,
                        style: PremiumTextStyles.caption.copyWith(
                          color: isSelected 
                              ? PremiumColors.primary
                              : PremiumColors.textTertiary,
                          fontWeight: isSelected 
                              ? FontWeight.w600 
                              : FontWeight.w400,
                        ),
                        child: Text(item.label),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class GlassmorphicNavigationItem {
  final IconData icon;
  final String label;

  const GlassmorphicNavigationItem({
    required this.icon,
    required this.label,
  });
}

/// プレミアムなプログレスバー
class GlassmorphicProgressBar extends StatelessWidget {
  final double progress;
  final double height;
  final Color? progressColor;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final bool showGlow;
  final String? label;

  const GlassmorphicProgressBar({
    Key? key,
    required this.progress,
    this.height = 12,
    this.progressColor,
    this.backgroundColor,
    this.borderRadius,
    this.showGlow = true,
    this.label,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveProgressColor = progressColor ?? PremiumColors.primary;
    final effectiveBackgroundColor = backgroundColor ?? PremiumColors.surfaceDark;
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(height / 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: PremiumTextStyles.caption),
          const SizedBox(height: 8),
        ],
        Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: effectiveBorderRadius,
            boxShadow: showGlow ? [
              BoxShadow(
                color: effectiveProgressColor.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ] : null,
          ),
          child: ClipRRect(
            borderRadius: effectiveBorderRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: effectiveBackgroundColor,
                  border: Border.all(
                    color: PremiumColors.borderLight,
                    width: 0.5,
                  ),
                ),
                child: Stack(
                  children: [
                    // プログレス部分
                    FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              effectiveProgressColor,
                              effectiveProgressColor.withOpacity(0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // グロー効果
                    if (showGlow && progress > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: FractionallySizedBox(
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  effectiveProgressColor.withOpacity(0.6),
                                  Colors.transparent,
                                ],
                                stops: const [0.8, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// プレミアムなスライダー
class GlassmorphicSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final String? label;
  final Color? activeColor;
  final Color? inactiveColor;

  const GlassmorphicSlider({
    Key? key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    this.onChanged,
    this.label,
    this.activeColor,
    this.inactiveColor,
  }) : super(key: key);

  @override
  State<GlassmorphicSlider> createState() => _GlassmorphicSliderState();
}

class _GlassmorphicSliderState extends State<GlassmorphicSlider> {
  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = widget.activeColor ?? PremiumColors.primary;
    final effectiveInactiveColor = widget.inactiveColor ?? PremiumColors.surfaceDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.label!, style: PremiumTextStyles.caption),
              Text(
                widget.value.toStringAsFixed(1),
                style: PremiumTextStyles.caption.copyWith(
                  color: effectiveActiveColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        GlassmorphicWidget(
          blur: 8,
          opacity: 0.08,
          borderColor: PremiumColors.borderLight,
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: effectiveActiveColor,
              inactiveTrackColor: effectiveInactiveColor,
              thumbColor: effectiveActiveColor,
              overlayColor: effectiveActiveColor.withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              trackHeight: 4,
            ),
            child: Slider(
              value: widget.value,
              min: widget.min,
              max: widget.max,
              onChanged: widget.onChanged,
            ),
          ),
        ),
      ],
    );
  }
}