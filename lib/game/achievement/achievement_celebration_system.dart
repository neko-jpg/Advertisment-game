import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../effects/impact_effect_system.dart';
import '../ui/premium/glassmorphic_widget.dart';
import 'celebration_particles.dart';

/// 記録達成時の豪華な祝福演出システム
class AchievementCelebrationSystem {
  final ParticleEngine _particleEngine;
  
  // 祝福エフェクト状態
  bool _isCelebrating = false;
  DateTime? _celebrationStartTime;
  
  // 音響効果
  static const String _fanfareSound = 'sounds/fanfare_celebration.mp3';
  static const String _recordBeatSound = 'sounds/record_beat.mp3';
  static const String _triumphMusic = 'sounds/triumph_theme.mp3';
  
  AchievementCelebrationSystem({
    required ParticleEngine particleEngine,
  }) : _particleEngine = particleEngine;

  /// 新記録達成時の祝福演出を開始
  Future<void> celebrateNewRecord({
    required int newScore,
    required int previousRecord,
    required BuildContext context,
  }) async {
    if (_isCelebrating) return;
    
    _isCelebrating = true;
    _celebrationStartTime = DateTime.now();
    
    // ハプティックフィードバック
    await HapticFeedback.heavyImpact();
    
    // 段階的な祝福演出
    await _executeRecordCelebrationSequence(
      newScore: newScore,
      previousRecord: previousRecord,
      context: context,
    );
  }
  
  /// 祝福演出シーケンスの実行
  Future<void> _executeRecordCelebrationSequence({
    required int newScore,
    required int previousRecord,
    required BuildContext context,
  }) async {
    // Phase 1: 衝撃的な瞬間 (0-1秒)
    await _triggerImpactMoment();
    
    // Phase 2: 爆発的な祝福 (1-3秒)
    await _triggerExplosiveCelebration(newScore, previousRecord);
    
    // Phase 3: 感動的な音楽 (2-8秒)
    _playTriumphantMusic();
    
    // Phase 4: 記録表示とシェア (3-10秒)
    await _showRecordDisplay(newScore, previousRecord, context);
    
    // Phase 5: 余韻とフェードアウト (8-12秒)
    await _fadeOutCelebration();
    
    _isCelebrating = false;
  }
  
  /// Phase 1: 衝撃的な瞬間
  Future<void> _triggerImpactMoment() async {
    // 時間停止効果
    await Future.delayed(const Duration(milliseconds: 200));
    
    // 衝撃波エフェクト（簡単な爆発エフェクトで代用）
    _particleEngine.emit(
      ExplosionParticles(
        position: const Offset(400, 300),
        particleCount: 50,
        color: const Color(0xFF00D4FF),
        intensity: 1.0,
      ),
    );
    
    await Future.delayed(const Duration(milliseconds: 800));
  }
  
  /// Phase 2: 爆発的な祝福
  Future<void> _triggerExplosiveCelebration(int newScore, int previousRecord) async {
    // 中央爆発エフェクト
    _particleEngine.emit(
      ExplosionParticles(
        position: const Offset(400, 300),
        particleCount: 200,
        color: const Color(0xFFFFD700),
        intensity: 1.5,
      ),
    );
    
    // 連続花火エフェクト
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      _triggerFireworkBurst(
        Offset(200 + i * 100, 150 + (i % 2) * 200),
      );
    }
  }
  
  /// 花火バーストエフェクト
  void _triggerFireworkBurst(Offset position) {
    _particleEngine.emit(
      ExplosionParticles(
        position: position,
        particleCount: 50,
        color: const Color(0xFFFF6B6B),
        intensity: 0.8,
      ),
    );
  }
  
  /// Phase 3: 感動的な音楽再生
  void _playTriumphantMusic() {
    // 実装時は実際の音響システムと統合
    // AudioManager.playSound(_fanfareSound);
    // AudioManager.playBackgroundMusic(_triumphMusic, fadeIn: true);
  }
  
  /// Phase 4: 記録表示とシェア機能
  Future<void> _showRecordDisplay(
    int newScore,
    int previousRecord,
    BuildContext context,
  ) async {
    // 記録表示ダイアログを表示
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RecordAchievementDialog(
        newScore: newScore,
        previousRecord: previousRecord,
        onShare: () => _shareAchievement(newScore),
        onContinue: () => Navigator.of(context).pop(),
      ),
    );
  }
  
  /// Phase 5: 余韻とフェードアウト
  Future<void> _fadeOutCelebration() async {
    // パーティクルエフェクトの段階的フェードアウト
    await Future.delayed(const Duration(seconds: 2));
    
    // 音楽のフェードアウト
    // AudioManager.fadeOutBackgroundMusic(duration: 2000);
    
    await Future.delayed(const Duration(seconds: 2));
  }
  
  /// 達成記録のシェア機能
  Future<void> _shareAchievement(int score) async {
    final shareText = '🎉 新記録達成！ $score点を獲得しました！ #PremiumGame';
    
    // 実装時は実際のシェア機能と統合
    // await Share.share(shareText);
  }
  
  /// 現在祝福中かどうか
  bool get isCelebrating => _isCelebrating;
  
  /// 祝福演出の経過時間
  Duration? get celebrationDuration {
    if (_celebrationStartTime == null) return null;
    return DateTime.now().difference(_celebrationStartTime!);
  }
}

/// 記録達成ダイアログ
class RecordAchievementDialog extends StatefulWidget {
  final int newScore;
  final int previousRecord;
  final VoidCallback onShare;
  final VoidCallback onContinue;
  
  const RecordAchievementDialog({
    Key? key,
    required this.newScore,
    required this.previousRecord,
    required this.onShare,
    required this.onContinue,
  }) : super(key: key);
  
  @override
  State<RecordAchievementDialog> createState() => _RecordAchievementDialogState();
}

class _RecordAchievementDialogState extends State<RecordAchievementDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    // アニメーション開始
    _scaleController.forward();
    _glowController.repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _scaleController.dispose();
    _glowController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _glowAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GlassmorphicWidget(
              blur: 20,
              opacity: 0.2,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 祝福アイコン
                    Container(
                      width: 120,
                      height: 120,
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
                              0.5 + 0.3 * _glowAnimation.value,
                            ),
                            blurRadius: 30 + 20 * _glowAnimation.value,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 祝福メッセージ
                    Text(
                      '🎉 新記録達成！ 🎉',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 0),
                            blurRadius: 20,
                            color: const Color(0xFF00D4FF).withOpacity(
                              0.8 + 0.2 * _glowAnimation.value,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // スコア表示
                    _buildScoreDisplay(),
                    
                    const SizedBox(height: 32),
                    
                    // アクションボタン
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(
                          icon: Icons.share,
                          label: 'シェア',
                          onTap: widget.onShare,
                          color: const Color(0xFF9D4EDD),
                        ),
                        _buildActionButton(
                          icon: Icons.play_arrow,
                          label: '続ける',
                          onTap: widget.onContinue,
                          color: const Color(0xFF00D4FF),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildScoreDisplay() {
    final improvement = widget.newScore - widget.previousRecord;
    
    return Column(
      children: [
        // 新スコア
        Text(
          '${widget.newScore}',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: Color(0xFFFFD700),
            shadows: [
              Shadow(
                offset: Offset(0, 0),
                blurRadius: 15,
                color: Color(0xFFFFD700),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // 改善値
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF4CAF50),
              width: 1,
            ),
          ),
          child: Text(
            '+$improvement点 向上！',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4CAF50),
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // 前回記録
        Text(
          '前回記録: ${widget.previousRecord}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color,
              color.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}