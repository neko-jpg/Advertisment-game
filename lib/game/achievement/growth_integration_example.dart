import 'package:flutter/material.dart';
import 'growth_effect_system.dart';
import '../effects/impact_effect_system.dart';
import '../ui/premium/glassmorphic_widget.dart';

/// 成長演出システムの統合使用例
class GrowthIntegrationExample extends StatefulWidget {
  const GrowthIntegrationExample({Key? key}) : super(key: key);
  
  @override
  State<GrowthIntegrationExample> createState() => _GrowthIntegrationExampleState();
}

class _GrowthIntegrationExampleState extends State<GrowthIntegrationExample> {
  late GrowthEffectSystem _growthSystem;
  late ParticleEngine _particleEngine;
  
  // プレイヤー状態
  int _currentLevel = 1;
  int _experience = 0;
  int _experienceToNext = 100;
  
  // 能力値
  Map<String, int> _stats = {
    'HP': 100,
    'MP': 50,
    '攻撃力': 25,
    '防御力': 20,
    'スピード': 15,
  };
  
  // 解放可能なコンテンツ
  final Map<int, Map<String, String>> _levelRewards = {
    2: {'新しい線種': '弾力線'},
    3: {'新機能': 'コンボシステム'},
    5: {'新エリア': '森の迷宮', '新しい線種': '氷線'},
    7: {'新スキル': '時間減速'},
    10: {'新エリア': '火山洞窟', '新しい線種': '炎線', 'スペシャル': '爆発攻撃'},
    15: {'新エリア': '雷の神殿', '新しい線種': '雷線', '究極技': '雷神召喚'},
  };
  
  @override
  void initState() {
    super.initState();
    
    // システム初期化
    _particleEngine = ParticleEngine();
    _growthSystem = GrowthEffectSystem(
      particleEngine: _particleEngine,
    );
  }
  
  void _gainExperience(int amount) async {
    setState(() {
      _experience += amount;
    });
    
    // レベルアップチェック
    while (_experience >= _experienceToNext) {
      await _levelUp();
    }
  }
  
  Future<void> _levelUp() async {
    final previousLevel = _currentLevel;
    
    setState(() {
      _experience -= _experienceToNext;
      _currentLevel++;
      _experienceToNext = (_experienceToNext * 1.2).round();
      
      // 能力値上昇
      _stats = _stats.map((key, value) {
        final increase = _calculateStatIncrease(key, _currentLevel);
        return MapEntry(key, value + increase);
      });
    });
    
    // レベルアップ演出
    final unlockedContent = _levelRewards[_currentLevel];
    
    await _growthSystem.showLevelUpEffect(
      newLevel: _currentLevel,
      previousLevel: previousLevel,
      context: context,
      unlockedContent: unlockedContent,
    );
  }
  
  int _calculateStatIncrease(String statName, int level) {
    switch (statName) {
      case 'HP':
        return 15 + (level ~/ 3) * 5;
      case 'MP':
        return 8 + (level ~/ 2) * 3;
      case '攻撃力':
        return 3 + (level ~/ 4) * 2;
      case '防御力':
        return 2 + (level ~/ 5) * 2;
      case 'スピード':
        return 1 + (level ~/ 6);
      default:
        return 1;
    }
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
                
                const SizedBox(height: 20),
                
                // レベル・経験値表示
                _buildLevelDisplay(),
                
                const SizedBox(height: 20),
                
                // 能力値表示
                _buildStatsDisplay(),
                
                const SizedBox(height: 20),
                
                // 経験値獲得ボタン
                _buildExperienceButtons(),
                
                const Spacer(),
                
                // デバッグ情報
                _buildDebugInfo(),
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: const Column(
          children: [
            Text(
              '成長システム デモ',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'レベルアップ時の豪華な成長演出をテスト',
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
  
  Widget _buildLevelDisplay() {
    final experienceProgress = _experience / _experienceToNext;
    
    return GlassmorphicWidget(
      blur: 15,
      opacity: 0.1,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // レベル表示
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'レベル $_currentLevel',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD700),
                    shadows: [
                      Shadow(
                        offset: Offset(0, 0),
                        blurRadius: 10,
                        color: Color(0xFFFFD700),
                      ),
                    ],
                  ),
                ),
                if (_growthSystem.isShowingGrowthEffect)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4CAF50),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'レベルアップ中',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 経験値バー
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '経験値',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '$_experience / $_experienceToNext',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: experienceProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF00D4FF),
                            Color(0xFF9D4EDD),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatsDisplay() {
    return GlassmorphicWidget(
      blur: 15,
      opacity: 0.1,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '能力値',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 能力値グリッド
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _stats.length,
              itemBuilder: (context, index) {
                final entry = _stats.entries.elementAt(index);
                return _buildStatCard(entry.key, entry.value);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(String statName, int value) {
    final colors = {
      'HP': const Color(0xFF4CAF50),
      'MP': const Color(0xFF2196F3),
      '攻撃力': const Color(0xFFFF6B6B),
      '防御力': const Color(0xFFFF9800),
      'スピード': const Color(0xFF9C27B0),
    };
    
    final color = colors[statName] ?? const Color(0xFF00D4FF);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            statName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildExperienceButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildExpButton(
                label: '+10 EXP',
                amount: 10,
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildExpButton(
                label: '+50 EXP',
                amount: 50,
                color: const Color(0xFF2196F3),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: _buildExpButton(
                label: '+100 EXP',
                amount: 100,
                color: const Color(0xFFFF9800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildExpButton(
                label: 'レベルアップ',
                amount: _experienceToNext - _experience,
                color: const Color(0xFFFFD700),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildExpButton({
    required String label,
    required int amount,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => _gainExperience(amount),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
  
  Widget _buildDebugInfo() {
    return GlassmorphicWidget(
      blur: 15,
      opacity: 0.05,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            const Text(
              'デバッグ情報',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white60,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '次のレベル報酬: ${_levelRewards[_currentLevel + 1]?.keys.join(', ') ?? 'なし'}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white50,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '成長演出中: ${_growthSystem.isShowingGrowthEffect ? 'はい' : 'いいえ'}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white50,
              ),
            ),
          ],
        ),
      ),
    );
  }
}