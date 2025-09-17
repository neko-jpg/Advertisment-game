import 'package:flutter/material.dart';
import 'achievement_manager.dart';
import 'achievement_celebration_system.dart';
import '../effects/impact_effect_system.dart';
import '../ui/premium/glassmorphic_widget.dart';

/// 達成システムの統合使用例
class AchievementIntegrationExample extends StatefulWidget {
  const AchievementIntegrationExample({Key? key}) : super(key: key);
  
  @override
  State<AchievementIntegrationExample> createState() => _AchievementIntegrationExampleState();
}

class _AchievementIntegrationExampleState extends State<AchievementIntegrationExample>
    with TickerProviderStateMixin {
  late AchievementManager _achievementManager;
  late ParticleEngine _particleEngine;
  
  // ゲーム状態
  int _currentGameScore = 0;
  bool _isGameActive = false;
  
  @override
  void initState() {
    super.initState();
    
    // システム初期化
    _particleEngine = ParticleEngine();
    _achievementManager = AchievementManager(
      particleEngine: _particleEngine,
    );
    
    // コールバック設定
    _setupAchievementCallbacks();
    
    // 記録読み込み
    _loadSavedRecords();
  }
  
  void _setupAchievementCallbacks() {
    // 新記録達成時のコールバック
    _achievementManager.onNewRecord = (newScore, previousRecord) {
      print('🎉 新記録達成！ $newScore点 (前回: $previousRecord点)');
      
      // 即座に祝福演出を実行することも可能
      // _achievementManager.celebrateNewRecord(context);
    };
    
    // スコア更新時のコールバック
    _achievementManager.onScoreUpdate = (score) {
      setState(() {
        _currentGameScore = score;
      });
    };
  }
  
  Future<void> _loadSavedRecords() async {
    await _achievementManager.loadRecords();
    setState(() {});
  }
  
  void _startGame() {
    setState(() {
      _isGameActive = true;
      _currentGameScore = 0;
    });
  }
  
  void _endGame() async {
    setState(() {
      _isGameActive = false;
    });
    
    // ゲーム終了時の達成チェック
    await _achievementManager.checkAchievements(context);
    
    // 記録保存
    await _achievementManager.saveRecords();
  }
  
  void _simulateScoreIncrease() {
    if (!_isGameActive) return;
    
    final newScore = _currentGameScore + (50 + (DateTime.now().millisecond % 100));
    _achievementManager.updateScore(newScore);
  }
  
  void _simulateHighScore() {
    if (!_isGameActive) return;
    
    final highScore = _achievementManager.bestScore + 500;
    _achievementManager.updateScore(highScore);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0F23),
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ヘッダー
                _buildHeader(),
                
                const SizedBox(height: 30),
                
                // スコア表示
                _buildScoreDisplay(),
                
                const SizedBox(height: 30),
                
                // ゲームコントロール
                _buildGameControls(),
                
                const SizedBox(height: 30),
                
                // 達成状態表示
                _buildAchievementStatus(),
                
                const Spacer(),
                
                // デバッグコントロール
                _buildDebugControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return GlassmorphicWidget(
      blur: 15,
      opacity: 0.1,
      borderRadius: 20,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: const Column(
          children: [
            Text(
              '達成システム デモ',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '新記録達成時の豪華な祝福演出をテスト',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildScoreDisplay() {
    return Row(
      children: [
        Expanded(
          child: _buildScoreCard(
            title: '現在のスコア',
            score: _currentGameScore,
            color: const Color(0xFF00D4FF),
            icon: Icons.sports_score,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildScoreCard(
            title: '最高記録',
            score: _achievementManager.bestScore,
            color: const Color(0xFFFFD700),
            icon: Icons.emoji_events,
          ),
        ),
      ],
    );
  }
  
  Widget _buildScoreCard({
    required String title,
    required int score,
    required Color color,
    required IconData icon,
  }) {
    return GlassmorphicWidget(
      blur: 15,
      opacity: 0.1,
      borderRadius: 16,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$score',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: color,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 0),
                    blurRadius: 10,
                    color: color.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGameControls() {
    return Column(
      children: [
        if (!_isGameActive) ...[
          _buildControlButton(
            label: 'ゲーム開始',
            icon: Icons.play_arrow,
            color: const Color(0xFF4CAF50),
            onTap: _startGame,
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _buildControlButton(
                  label: 'スコア+',
                  icon: Icons.add,
                  color: const Color(0xFF00D4FF),
                  onTap: _simulateScoreIncrease,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildControlButton(
                  label: '新記録！',
                  icon: Icons.star,
                  color: const Color(0xFFFFD700),
                  onTap: _simulateHighScore,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildControlButton(
            label: 'ゲーム終了',
            icon: Icons.stop,
            color: const Color(0xFFFF6B6B),
            onTap: _endGame,
          ),
        ],
      ],
    );
  }
  
  Widget _buildControlButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
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
  
  Widget _buildAchievementStatus() {
    return GlassmorphicWidget(
      blur: 15,
      opacity: 0.1,
      borderRadius: 16,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '達成状態',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 15),
            _buildStatusItem(
              label: '新記録達成',
              value: _achievementManager.hasNewRecord,
              trueColor: const Color(0xFFFFD700),
            ),
            _buildStatusItem(
              label: 'セッション記録',
              value: _achievementManager.hasSessionRecord,
              trueColor: const Color(0xFF9D4EDD),
            ),
            _buildStatusItem(
              label: '祝福演出中',
              value: _achievementManager.isCelebrating,
              trueColor: const Color(0xFF00D4FF),
            ),
            const SizedBox(height: 10),
            Text(
              'セッション最高: ${_achievementManager.sessionBestScore}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusItem({
    required String label,
    required bool value,
    required Color trueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? trueColor : Colors.grey.withOpacity(0.3),
              boxShadow: value ? [
                BoxShadow(
                  color: trueColor.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: value ? Colors.white : Colors.white60,
              fontWeight: value ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDebugControls() {
    return GlassmorphicWidget(
      blur: 15,
      opacity: 0.05,
      borderRadius: 12,
      child: Container(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            const Text(
              'デバッグ機能',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildDebugButton(
                    label: 'リセット',
                    onTap: () {
                      _achievementManager.resetRecords();
                      setState(() {
                        _currentGameScore = 0;
                        _isGameActive = false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDebugButton(
                    label: '祝福テスト',
                    onTap: () async {
                      // 直接祝福演出をテスト
                      _achievementManager.updateScore(9999);
                      await _achievementManager.checkAchievements(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDebugButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}