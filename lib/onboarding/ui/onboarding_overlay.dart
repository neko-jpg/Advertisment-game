/// Onboarding overlay widget that displays tutorial guides and messages
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../onboarding_manager.dart';
import '../models/onboarding_models.dart';

/// Overlay widget that displays onboarding elements over the game
class OnboardingOverlay extends StatefulWidget {
  const OnboardingOverlay({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingManager>(
      builder: (context, onboarding, child) {
        return Stack(
          children: [
            widget.child,
            
            // Visual guide overlay
            if (onboarding.visualGuide.currentGuide != null)
              _buildVisualGuideOverlay(onboarding.visualGuide.currentGuide!),
            
            // Tutorial message overlay
            if (onboarding.isOnboardingActive)
              _buildTutorialMessageOverlay(onboarding),
            
            // Motivation message overlay
            if (onboarding.motivation.currentMessage != null)
              _buildMotivationMessageOverlay(onboarding.motivation.currentMessage!),
            
            // Progress indicator
            if (onboarding.isOnboardingActive)
              _buildProgressIndicator(onboarding),
            
            // Skip button
            if (onboarding.isOnboardingActive)
              _buildSkipButton(onboarding),
          ],
        );
      },
    );
  }

  /// Build visual guide overlay
  Widget _buildVisualGuideOverlay(VisualGuide guide) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: VisualGuidePainter(
            guide: guide,
            animation: guide.animated ? _pulseAnimation : null,
          ),
        ),
      ),
    );
  }

  /// Build tutorial message overlay
  Widget _buildTutorialMessageOverlay(OnboardingManager onboarding) {
    final message = onboarding.currentTutorialMessage;
    final hint = onboarding.currentTutorialHint;
    
    if (message.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 100,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              if (hint.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  hint,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build motivation message overlay
  Widget _buildMotivationMessageOverlay(MotivationMessage message) {
    Color backgroundColor;
    Color borderColor;
    IconData icon;

    switch (message.type) {
      case MotivationType.encouragement:
        backgroundColor = Colors.green.withOpacity(0.9);
        borderColor = Colors.green;
        icon = Icons.thumb_up;
        break;
      case MotivationType.progress:
        backgroundColor = Colors.blue.withOpacity(0.9);
        borderColor = Colors.blue;
        icon = Icons.trending_up;
        break;
      case MotivationType.reward:
        backgroundColor = Colors.orange.withOpacity(0.9);
        borderColor = Colors.orange;
        icon = Icons.card_giftcard;
        break;
      case MotivationType.comeback:
        backgroundColor = Colors.purple.withOpacity(0.9);
        borderColor = Colors.purple;
        icon = Icons.waving_hand;
        break;
      case MotivationType.achievement:
        backgroundColor = Colors.amber.withOpacity(0.9);
        borderColor = Colors.amber;
        icon = Icons.emoji_events;
        break;
    }

    return Positioned(
      top: MediaQuery.of(context).size.height * 0.3,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    message.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                message.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              if (message.reward != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.yellow, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '+${message.reward} coins',
                      style: const TextStyle(
                        color: Colors.yellow,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
              if (message.actionText != null) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    context.read<OnboardingManager>().motivation.hideMotivationMessage();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: backgroundColor.withOpacity(1.0),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(message.actionText!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build progress indicator
  Widget _buildProgressIndicator(OnboardingManager onboarding) {
    final progress = onboarding.fastOnboarding.progress;
    if (progress == null) return const SizedBox.shrink();

    final totalSteps = TutorialStep.values.length - 1; // Exclude completed
    final completedSteps = progress.completedSteps.length;
    final progressValue = completedSteps / totalSteps;

    return Positioned(
      top: 50,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tutorial Progress',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                Text(
                  '$completedSteps/$totalSteps',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progressValue,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        ),
      ),
    );
  }

  /// Build skip button
  Widget _buildSkipButton(OnboardingManager onboarding) {
    return Positioned(
      top: 50,
      right: 20,
      child: TextButton(
        onPressed: () => onboarding.skipOnboarding(),
        style: TextButton.styleFrom(
          backgroundColor: Colors.black.withOpacity(0.7),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: const Text('Skip'),
      ),
    );
  }
}

/// Custom painter for visual guides
class VisualGuidePainter extends CustomPainter {
  const VisualGuidePainter({
    required this.guide,
    this.animation,
  });

  final VisualGuide guide;
  final Animation<double>? animation;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final fillPaint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final position = Offset(
      guide.position.dx * size.width,
      guide.position.dy * size.height,
    );

    final scale = animation?.value ?? 1.0;

    switch (guide.type) {
      case GuideType.tap:
        _drawTapGuide(canvas, position, paint, fillPaint, scale);
        break;
      case GuideType.hold:
        _drawHoldGuide(canvas, position, paint, fillPaint, scale);
        break;
      case GuideType.swipe:
        _drawSwipeGuide(canvas, position, paint, fillPaint, scale);
        break;
      case GuideType.draw:
        _drawDrawGuide(canvas, position, paint, fillPaint, scale);
        break;
      case GuideType.highlight:
        _drawHighlightGuide(canvas, position, paint, fillPaint, scale);
        break;
    }

    // Draw message
    _drawMessage(canvas, position, size);
  }

  void _drawTapGuide(Canvas canvas, Offset position, Paint paint, Paint fillPaint, double scale) {
    final radius = 30.0 * scale;
    canvas.drawCircle(position, radius, fillPaint);
    canvas.drawCircle(position, radius, paint);
    
    // Draw tap indicator
    final innerRadius = 10.0 * scale;
    canvas.drawCircle(position, innerRadius, paint..style = PaintingStyle.fill);
  }

  void _drawHoldGuide(Canvas canvas, Offset position, Paint paint, Paint fillPaint, double scale) {
    final radius = 40.0 * scale;
    canvas.drawCircle(position, radius, fillPaint);
    canvas.drawCircle(position, radius, paint);
    
    // Draw hold indicator (concentric circles)
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(position, (15.0 * i * scale), paint..style = PaintingStyle.stroke);
    }
  }

  void _drawSwipeGuide(Canvas canvas, Offset position, Paint paint, Paint fillPaint, double scale) {
    final startPos = position;
    final endPos = Offset(position.dx + 100 * scale, position.dy);
    
    // Draw arrow
    canvas.drawLine(startPos, endPos, paint..strokeWidth = 4);
    
    // Draw arrowhead
    final arrowPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    
    final arrowPath = Path();
    arrowPath.moveTo(endPos.dx, endPos.dy);
    arrowPath.lineTo(endPos.dx - 15 * scale, endPos.dy - 8 * scale);
    arrowPath.lineTo(endPos.dx - 15 * scale, endPos.dy + 8 * scale);
    arrowPath.close();
    
    canvas.drawPath(arrowPath, arrowPaint);
  }

  void _drawDrawGuide(Canvas canvas, Offset position, Paint paint, Paint fillPaint, double scale) {
    // Draw wavy line to indicate drawing
    final path = Path();
    path.moveTo(position.dx - 50 * scale, position.dy);
    
    for (double x = -50; x <= 50; x += 10) {
      final y = position.dy + math.sin(x * 0.1) * 20 * scale;
      path.lineTo(position.dx + x * scale, y);
    }
    
    canvas.drawPath(path, paint..strokeWidth = 4);
  }

  void _drawHighlightGuide(Canvas canvas, Offset position, Paint paint, Paint fillPaint, double scale) {
    final rect = Rect.fromCenter(
      center: position,
      width: 80 * scale,
      height: 60 * scale,
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(8 * scale)),
      fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(8 * scale)),
      paint,
    );
  }

  void _drawMessage(Canvas canvas, Offset position, Size size) {
    if (guide.message.isEmpty) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: guide.message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: size.width * 0.6);

    // Position text above the guide
    final textPosition = Offset(
      position.dx - textPainter.width / 2,
      position.dy - 80,
    );

    // Draw background
    final backgroundRect = Rect.fromLTWH(
      textPosition.dx - 8,
      textPosition.dy - 4,
      textPainter.width + 16,
      textPainter.height + 8,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(backgroundRect, const Radius.circular(4)),
      Paint()..color = Colors.black.withOpacity(0.8),
    );

    textPainter.paint(canvas, textPosition);
  }

  @override
  bool shouldRepaint(covariant VisualGuidePainter oldDelegate) {
    return oldDelegate.guide != guide || oldDelegate.animation != animation;
  }
}