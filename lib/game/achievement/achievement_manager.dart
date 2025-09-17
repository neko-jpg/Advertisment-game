import 'package:flutter/material.dart';
import 'achievement_celebration_system.dart';
import '../effects/impact_effect_system.dart';

/// 達成システム全体を管理するマネージャー
class AchievementManager {
  final AchievementCelebrationSystem _celebrationSystem;
  
  // 記録管理
  int _currentScore = 0;
  int _bestScore = 0;
  int _sessionBestScore = 0;
  
  // 達成状態
  bool _hasNewRecord = false;
  bool _hasSessionRecord = false;
  
  // コールバック
  Function(int newScore, int previousRecord)? onNewRecord;
  Function(int score)? onScoreUpdate;
  
  AchievementManager({
    required ParticleEngine particleEngine,
  }) : _celebrationSystem = AchievementCelebrationSystem(
         particleEngine: particleEngine,
       );
  
  /// 現在のスコアを更新
  void updateScore(int score) {
    _currentScore = score;
    
    // セッション記録チェック
    if (score > _sessionBestScore) {
      _sessionBestScore = score;
      _hasSessionRecord = true;
    }
    
    // 全体記録チェック
    if (score > _bestScore) {
      final previousRecord = _bestScore;
      _bestScore = score;
      _hasNewRecord = true;
      
      // 新記録コールバック
      onNewRecord?.call(score, previousRecord);
    }
    
    // スコア更新コールバック
    onScoreUpdate?.call(score);
  }
  
  /// 新記録達成時の祝福演出を実行
  Future<void> celebrateNewRecord(BuildContext context) async {
    if (!_hasNewRecord) return;
    
    await _celebrationSystem.celebrateNewRecord(
      newScore: _currentScore,
      previousRecord: _bestScore - (_currentScore - _bestScore),
      context: context,
    );
    
    _hasNewRecord = false;
  }
  
  /// ゲーム終了時の達成チェック
  Future<void> checkAchievements(BuildContext context) async {
    if (_hasNewRecord) {
      await celebrateNewRecord(context);
    } else if (_hasSessionRecord) {
      await _celebrateSessionRecord(context);
    }
  }
  
  /// セッション記録達成の演出
  Future<void> _celebrateSessionRecord(BuildContext context) async {
    // セッション記録用の軽い演出
    await showDialog(
      context: context,
      builder: (context) => SessionRecordDialog(
        score: _sessionBestScore,
        onContinue: () => Navigator.of(context).pop(),
      ),
    );
    
    _hasSessionRecord = false;
  }
  
  /// 記録をリセット（デバッグ用）
  void resetRecords() {
    _bestScore = 0;
    _sessionBestScore = 0;
    _currentScore = 0;
    _hasNewRecord = false;
    _hasSessionRecord = false;
  }
  
  /// 記録を保存
  Future<void> saveRecords() async {
    // 実装時は実際のストレージシステムと統合
    // await SharedPreferences.getInstance().then((prefs) {
    //   prefs.setInt('best_score', _bestScore);
    // });
  }
  
  /// 記録を読み込み
  Future<void> loadRecords() async {
    // 実装時は実際のストレージシステムと統合
    // final prefs = await SharedPreferences.getInstance();
    // _bestScore = prefs.getInt('best_score') ?? 0;
  }
  
  // ゲッター
  int get currentScore => _currentScore;
  int get bestScore => _bestScore;
  int get sessionBestScore => _sessionBestScore;
  bool get hasNewRecord => _hasNewRecord;
  bool get hasSessionRecord => _hasSessionRecord;
  bool get isCelebrating => _celebrationSystem.isCelebrating;
}

/// セッション記録ダイアログ
class SessionRecordDialog extends StatefulWidget {
  final int score;
  final VoidCallback onContinue;
  
  const SessionRecordDialog({
    Key? key,
    required this.score,
    required this.onContinue,
  }) : super(key: key);
  
  @override
  State<SessionRecordDialog> createState() => _SessionRecordDialogState();
}

class _SessionRecordDialogState extends State<SessionRecordDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
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
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A1A2E),
                      Color(0xFF16213E),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF9D4EDD).withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9D4EDD).withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // アイコン
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF9D4EDD),
                            Color(0xFF00D4FF),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF9D4EDD).withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.trending_up,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // タイトル
                    const Text(
                      'セッション記録！',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // スコア
                    Text(
                      '${widget.score}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF9D4EDD),
                        shadows: [
                          Shadow(
                            offset: Offset(0, 0),
                            blurRadius: 10,
                            color: Color(0xFF9D4EDD),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // メッセージ
                    Text(
                      'このセッションでの最高スコアです！',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 続けるボタン
                    GestureDetector(
                      onTap: widget.onContinue,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF9D4EDD),
                              Color(0xFF00D4FF),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF9D4EDD).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Text(
                          '続ける',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}