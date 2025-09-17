import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../effects/impact_effect_system.dart';
import '../ui/premium/glassmorphic_widget.dart';
import 'dart:math' as math;

/// レベルアップ時の成長演出システム
class GrowthEffectSystem {
  final ParticleEngine _particleEngine;
  
  // 成長演出状態
  bool _isShowingGrowthEffect = false;
  
  GrowthEffectSystem({
    required ParticleEngine particleEngine,
  }) : _particleEngine = particleEngine;
  
  /// レベルアップ時の光の演出を実行
  Future<void> showLevelUpEffect({
    required int newLevel,
    required int previousLevel,
    required BuildContext context,
    Map<String, dynamic>? unlockedContent,
  }) async {
    if (_isShowingGrowthEffect) return;
    
    _isShowingGrowthEffect = true;
    
    try {
      // ハプティックフィードバック
      await HapticFeedback.mediumImpact();
      
      // 段階的な成長演出
      await _executeLevelUpSequence(
        newLevel: newLevel,
        previousLevel: previousLevel,
        context: context,
        unlockedContent: unlockedContent,
      );
    } finally {
      _isShowingGrowthEffect = false;
    }
  }
  
  /// レベルアップ演出シーケンス
  Future<void> _executeLevelUpSequence({
    required int newLevel,
    required int previousLevel,
    required BuildContext context,
    Map<String, dynamic>? unlockedContent,
  }) async {
    // Phase 1: 光の収束 (0-1秒)
    await _triggerLightConvergence();
    
    // Phase 2: レベルアップ爆発 (1-2秒)
    await _triggerLevelUpExplosion(newLevel);
    
    // Phase 3: 成長表示 (2-5秒)
    await _showGrowthDisplay(newLevel, previousLevel, context, unlockedContent);
    
    // Phase 4: 余韻エフェクト (4-6秒)
    await _fadeOutGrowthEffect();
  }
  
  /// Phase 1: 光の収束エフェクト
  Future<void> _triggerLightConvergence() async {
    // 周囲から中央に向かう光の粒子
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi;
      final startPos = Offset(
        400 + math.cos(angle) * 300,
        300 + math.sin(angle) * 300,
      );
      
      // 収束光エフェクト（簡易版として爆発エフェクトで代用）
      _particleEngine.emit(
        ExplosionParticles(
          position: startPos,
          particleCount: 10,
          color: Color.lerp(
            const Color(0xFF00D4FF),
            const Color(0xFFFFD700),
            i / 8,
          )!,
          intensity: 0.5,
        ),
      );
    }
    
    await Future.delayed(const Duration(milliseconds: 1000));
  }
  
  /// Phase 2: レベルアップ爆発エフェクト
  Future<void> _triggerLevelUpExplosion(int newLevel) async {
    // 中央からの光の爆発
    _particleEngine.emit(
      ExplosionParticles(
        position: const Offset(400, 300),
        particleCount: 100 + (newLevel * 10), // レベルに応じて増加
        color: const Color(0xFFFFD700),
        intensity: 1.2,
      ),
    );
    
    // レベル数に応じた追加エフェクト
    if (newLevel % 5 == 0) {
      // 5の倍数レベルは特別演出
      await _triggerSpecialLevelEffect(newLevel);
    }
    
    await Future.delayed(const Duration(milliseconds: 800));
  }
  
  /// 特別レベル（5の倍数）の演出
  Future<void> _triggerSpecialLevelEffect(int level) async {
    // 虹色の光の輪
    for (int i = 0; i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      
      _particleEngine.emit(
        ExplosionParticles(
          position: Offset(
            400 + math.cos(i * math.pi / 3) * 50,
            300 + math.sin(i * math.pi / 3) * 50,
          ),
          particleCount: 30,
          color: HSVColor.fromAHSV(1.0, i * 60.0, 1.0, 1.0).toColor(),
          intensity: 0.8,
        ),
      );
    }
  }
  
  /// Phase 3: 成長表示ダイアログ
  Future<void> _showGrowthDisplay(
    int newLevel,
    int previousLevel,
    BuildContext context,
    Map<String, dynamic>? unlockedContent,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LevelUpDialog(
        newLevel: newLevel,
        previousLevel: previousLevel,
        unlockedContent: unlockedContent,
        onContinue: () => Navigator.of(context).pop(),
      ),
    );
  }
  
  /// Phase 4: 余韻エフェクト
  Future<void> _fadeOutGrowthEffect() async {
    // 残光エフェクト
    _particleEngine.emit(
      ExplosionParticles(
        position: const Offset(400, 300),
        particleCount: 20,
        color: const Color(0xFFFFD700).withOpacity(0.3),
        intensity: 0.3,
      ),
    );
    
    await Future.delayed(const Duration(milliseconds: 1500));
  }
  
  /// 現在成長演出中かどうか
  bool get isShowingGrowthEffect => _isShowingGrowthEffect;
}

/// 収束する光のエミッター（簡易版）
class ConvergingLightEmitter {
  final Offset startPosition;
  final Offset targetPosition;
  final Color color;
  
  ConvergingLightEmitter({
    required this.startPosition,
    required this.targetPosition,
    required this.color,
  });
}

/// レベルアップダイアログ
class LevelUpDialog extends StatefulWidget {
  final int newLevel;
  final int previousLevel;
  final Map<String, dynamic>? unlockedContent;
  final VoidCallback onContinue;
  
  const LevelUpDialog({
    Key? key,
    required this.newLevel,
    required this.previousLevel,
    this.unlockedContent,
    required this.onContinue,
  }) : super(key: key);
  
  @override
  State<LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<LevelUpDialog>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _glowController;
  late AnimationController _numberController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<int> _numberAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _numberController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: Curves.elasticOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    _numberAnimation = IntTween(
      begin: widget.previousLevel,
      end: widget.newLevel,
    ).animate(CurvedAnimation(
      parent: _numberController,
      curve: Curves.easeOut,
    ));
    
    // アニメーション開始
    _startAnimations();
  }
  
  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _mainController.forward();
    _glowController.repeat(reverse: true);
    
    await Future.delayed(const Duration(milliseconds: 400));
    _numberController.forward();
  }
  
  @override
  void dispose() {
    _mainController.dispose();
    _glowController.dispose();
    _numberController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _scaleAnimation,
          _glowAnimation,
          _numberAnimation,
        ]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GlassmorphicWidget(
              blur: 25,
              opacity: 0.15,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // レベルアップアイコン
                    _buildLevelUpIcon(),
                    
                    const SizedBox(height: 24),
                    
                    // レベルアップメッセージ
                    Text(
                      'レベルアップ！',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 0),
                            blurRadius: 20,
                            color: const Color(0xFFFFD700).withOpacity(
                              0.8 + 0.2 * _glowAnimation.value,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // レベル表示
                    _buildLevelDisplay(),
                    
                    const SizedBox(height: 30),
                    
                    // 解放コンテンツ表示
                    if (widget.unlockedContent != null)
                      _buildUnlockedContent(),
                    
                    const SizedBox(height: 30),
                    
                    // 続けるボタン
                    _buildContinueButton(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildLevelUpIcon() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Color.lerp(
              const Color(0xFFFFD700),
              const Color(0xFFFF6B6B),
              _glowAnimation.value,
            )!,
            const Color(0xFF9D4EDD),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(
              0.6 + 0.4 * _glowAnimation.value,
            ),
            blurRadius: 40 + 20 * _glowAnimation.value,
            spreadRadius: 8,
          ),
        ],
      ),
      child: const Icon(
        Icons.trending_up,
        size: 70,
        color: Colors.white,
      ),
    );
  }
  
  Widget _buildLevelDisplay() {
    return Column(
      children: [
        // 新レベル
        AnimatedBuilder(
          animation: _numberAnimation,
          builder: (context, child) {
            return Text(
              'Lv.${_numberAnimation.value}',
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD700),
                shadows: [
                  Shadow(
                    offset: Offset(0, 0),
                    blurRadius: 20,
                    color: Color(0xFFFFD700),
                  ),
                ],
              ),
            );
          },
        ),
        
        const SizedBox(height: 12),
        
        // レベル上昇表示
        if (widget.newLevel > widget.previousLevel)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF4CAF50),
                  Color(0xFF8BC34A),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              '+${widget.newLevel - widget.previousLevel} レベル上昇！',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildUnlockedContent() {
    final content = widget.unlockedContent!;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF9D4EDD).withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF9D4EDD).withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_open,
                color: const Color(0xFF9D4EDD),
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                '新機能解放！',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9D4EDD),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 解放されたコンテンツのリスト
          ...content.entries.map((entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF9D4EDD),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${entry.key}: ${entry.value}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
  
  Widget _buildContinueButton() {
    return GestureDetector(
      onTap: widget.onContinue,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFD700),
              Color(0xFFFF8C00),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_forward, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Text(
              '続ける',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 能力値上昇のビジュアル表現ウィジェット
class StatGrowthWidget extends StatefulWidget {
  final String statName;
  final int oldValue;
  final int newValue;
  final Color color;
  
  const StatGrowthWidget({
    Key? key,
    required this.statName,
    required this.oldValue,
    required this.newValue,
    this.color = const Color(0xFF00D4FF),
  }) : super(key: key);
  
  @override
  State<StatGrowthWidget> createState() => _StatGrowthWidgetState();
}

class _StatGrowthWidgetState extends State<StatGrowthWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _valueAnimation;
  late Animation<double> _progressAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _valueAnimation = IntTween(
      begin: widget.oldValue,
      end: widget.newValue,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 能力値名
              Text(
                widget.statName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: widget.color,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // 数値表示
              Row(
                children: [
                  Text(
                    '${_valueAnimation.value}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  
                  if (widget.newValue > widget.oldValue) ...[
                    const SizedBox(width: 8),
                    Text(
                      '+${widget.newValue - widget.oldValue}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 8),
              
              // プログレスバー
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progressAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.color,
                          widget.color.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}