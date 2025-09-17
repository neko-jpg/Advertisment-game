import 'package:flutter/material.dart';
import 'glassmorphic_widget.dart';
import 'glassmorphic_components.dart';
import 'premium_theme.dart';
import 'premium_animations.dart';
import 'chain_animation.dart';
import 'animation_controller_system.dart';

/// プレミアムUI統合例
class PremiumUIShowcase extends StatefulWidget {
  const PremiumUIShowcase({Key? key}) : super(key: key);

  @override
  State<PremiumUIShowcase> createState() => _PremiumUIShowcaseState();
}

class _PremiumUIShowcaseState extends State<PremiumUIShowcase>
    with TickerProviderStateMixin {
  int _selectedNavIndex = 0;
  double _sliderValue = 0.5;
  double _progressValue = 0.7;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: PremiumTheme.backgroundDecoration,
        child: SafeArea(
          child: Column(
            children: [
              // ヘッダー部分
              _buildHeader(),
              
              // メインコンテンツ
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildGlassmorphicCards(),
                      const SizedBox(height: 24),
                      _buildAnimatedButtons(),
                      const SizedBox(height: 24),
                      _buildProgressAndSliders(),
                      const SizedBox(height: 24),
                      _buildChainAnimationDemo(),
                    ],
                  ),
                ),
              ),
              
              // ナビゲーションバー
              _buildNavigationBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return PremiumPresetAnimation(
      preset: PremiumAnimationPreset.slideFromTop,
      delay: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GlassmorphicCard(
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: PremiumColors.primary,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium Game UI',
                      style: PremiumTextStyles.subtitle,
                    ),
                    Text(
                      'Glassmorphic Design System',
                      style: PremiumTextStyles.caption,
                    ),
                  ],
                ),
              ),
              GlassmorphicButton(
                onPressed: () {},
                padding: const EdgeInsets.all(12),
                borderRadius: BorderRadius.circular(12),
                child: const Icon(
                  Icons.settings,
                  color: PremiumColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassmorphicCards() {
    return Column(
      children: [
        // 基本カード
        PremiumPresetAnimation(
          preset: PremiumAnimationPreset.slideFromLeft,
          delay: const Duration(milliseconds: 400),
          child: GlassmorphicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: PremiumColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.star,
                        color: PremiumColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Premium Features',
                            style: PremiumTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Glassmorphic design with blur effects',
                            style: PremiumTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'This card demonstrates the glassmorphic effect with backdrop blur, '
                  'gradient borders, and subtle glow effects.',
                  style: PremiumTextStyles.caption,
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // スコアカード
        PremiumPresetAnimation(
          preset: PremiumAnimationPreset.slideFromRight,
          delay: const Duration(milliseconds: 600),
          child: GlassmorphicCard(
            borderColor: PremiumColors.accent,
            glowColor: PremiumColors.accent,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'High Score',
                        style: PremiumTextStyles.caption,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1,234,567',
                        style: PremiumTextStyles.score,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        PremiumColors.accent,
                        PremiumColors.accent.withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: PremiumColors.accent.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedButtons() {
    return Column(
      children: [
        // プライマリーボタン
        PremiumPresetAnimation(
          preset: PremiumAnimationPreset.scaleUp,
          delay: const Duration(milliseconds: 800),
          child: SizedBox(
            width: double.infinity,
            child: GlassmorphicButton(
              onPressed: () {
                // 成功アニメーションのデモ
                showDialog(
                  context: context,
                  builder: (context) => PremiumPresetAnimation(
                    preset: PremiumAnimationPreset.celebration,
                    child: GlassmorphicDialog(
                      title: 'Success!',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: PremiumColors.success,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Animation completed successfully!',
                            style: PremiumTextStyles.body,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      actions: [
                        GlassmorphicButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'OK',
                            style: PremiumTextStyles.button,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Start Premium Experience',
                style: PremiumTextStyles.button,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // セカンダリーボタン行
        PremiumPresetAnimation(
          preset: PremiumAnimationPreset.slideFromBottom,
          delay: const Duration(milliseconds: 1000),
          child: Row(
            children: [
              Expanded(
                child: GlassmorphicButton(
                  onPressed: () {},
                  borderColor: PremiumColors.secondary,
                  glowColor: PremiumColors.secondary,
                  child: Text(
                    'Settings',
                    style: PremiumTextStyles.button.copyWith(
                      color: PremiumColors.secondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GlassmorphicButton(
                  onPressed: () {},
                  borderColor: PremiumColors.warning,
                  glowColor: PremiumColors.warning,
                  child: Text(
                    'Help',
                    style: PremiumTextStyles.button.copyWith(
                      color: PremiumColors.warning,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressAndSliders() {
    return PremiumPresetAnimation(
      preset: PremiumAnimationPreset.slideFromLeft,
      delay: const Duration(milliseconds: 1200),
      child: GlassmorphicCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Game Progress',
              style: PremiumTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            // プログレスバー
            GlassmorphicProgressBar(
              progress: _progressValue,
              label: 'Level Progress',
              height: 16,
            ),
            
            const SizedBox(height: 24),
            
            // スライダー
            GlassmorphicSlider(
              value: _sliderValue,
              label: 'Volume',
              onChanged: (value) {
                setState(() {
                  _sliderValue = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChainAnimationDemo() {
    return PremiumPresetAnimation(
      preset: PremiumAnimationPreset.dramaticEntrance,
      delay: const Duration(milliseconds: 1400),
      child: GlassmorphicCard(
        child: Column(
          children: [
            Text(
              'Chain Animation Demo',
              style: PremiumTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAnimatedIcon(Icons.favorite, PremiumColors.accent, 0),
                _buildAnimatedIcon(Icons.star, PremiumColors.warning, 200),
                _buildAnimatedIcon(Icons.diamond, PremiumColors.primary, 400),
                _buildAnimatedIcon(Icons.auto_awesome, PremiumColors.secondary, 600),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon(IconData icon, Color color, int delayMs) {
    return ChainAnimation(
      steps: [
        ScaleStep(
          duration: const Duration(milliseconds: 300),
          delay: Duration(milliseconds: delayMs),
          begin: 0.0,
          end: 1.0,
          curve: Curves.elasticOut,
        ),
        RotateStep(
          duration: const Duration(milliseconds: 500),
          delay: Duration(milliseconds: 100),
          begin: 0.0,
          end: 0.25,
          curve: Curves.easeInOut,
        ),
        RotateStep(
          duration: const Duration(milliseconds: 500),
          delay: Duration(milliseconds: 100),
          begin: 0.25,
          end: 0.0,
          curve: Curves.easeInOut,
        ),
      ],
      repeat: true,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.6),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildNavigationBar() {
    return GlassmorphicNavigationBar(
      currentIndex: _selectedNavIndex,
      onTap: (index) {
        setState(() {
          _selectedNavIndex = index;
        });
      },
      items: const [
        GlassmorphicNavigationItem(
          icon: Icons.home,
          label: 'Home',
        ),
        GlassmorphicNavigationItem(
          icon: Icons.gamepad,
          label: 'Game',
        ),
        GlassmorphicNavigationItem(
          icon: Icons.leaderboard,
          label: 'Scores',
        ),
        GlassmorphicNavigationItem(
          icon: Icons.person,
          label: 'Profile',
        ),
      ],
    );
  }
}