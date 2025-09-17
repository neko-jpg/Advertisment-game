import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'impact_effect_system.dart';
import 'particle_engine.dart';
import 'slow_motion_manager.dart';

/// インパクトエフェクトシステムの統合例
class ImpactEffectIntegrationExample extends StatefulWidget {
  const ImpactEffectIntegrationExample({Key? key}) : super(key: key);

  @override
  State<ImpactEffectIntegrationExample> createState() => _ImpactEffectIntegrationExampleState();
}

class _ImpactEffectIntegrationExampleState extends State<ImpactEffectIntegrationExample>
    with TickerProviderStateMixin {
  late ImpactEffectSystem _impactSystem;
  late ParticleEngine _particleEngine;
  
  // デモ用状態
  int _score = 0;
  int _combo = 0;
  double _obstacleDistance = 200.0;
  bool _isObstacleApproaching = false;
  
  @override
  void initState() {
    super.initState();
    _particleEngine = ParticleEngine();
    _impactSystem = ImpactEffectSystem(_particleEngine);
    
    // デモ用タイマー
    _startDemoLoop();
  }
  
  void _startDemoLoop() {
    // 定期的にデモエフェクトを実行
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _triggerRandomEffect();
        _startDemoLoop();
      }
    });
  }
  
  void _triggerRandomEffect() {
    final random = math.Random();
    final effectType = random.nextInt(4);
    
    switch (effectType) {
      case 0:
        _triggerScoreEffect();
        break;
      case 1:
        _triggerComboEffect();
        break;
      case 2:
        _triggerSlowMotionEffect();
        break;
      case 3:
        _triggerDangerEffect();
        break;
    }
  }
  
  void _triggerScoreEffect() {
    final random = math.Random();
    final score = (random.nextInt(10) + 1) * 100;
    final position = Offset(
      random.nextDouble() * 300 + 50,
      random.nextDouble() * 400 + 100,
    );
    
    setState(() {
      _score += score;
    });
    
    _impactSystem.triggerScoreExplosion(position, score);
  }
  
  void _triggerComboEffect() {
    setState(() {
      _combo++;
    });
    
    final position = Offset(200, 300);
    _impactSystem.triggerComboEffect(_combo, position);
  }
  
  void _triggerSlowMotionEffect() {
    _impactSystem.startSlowMotion(
      2.0,
      factor: 0.3,
      type: SlowMotionType.precision,
    );
  }
  
  void _triggerDangerEffect() {
    setState(() {
      _isObstacleApproaching = true;
      _obstacleDistance = 50.0;
    });
    
    _impactSystem.triggerDangerSlowMotion(_obstacleDistance);
    
    // 障害物が通り過ぎる演出
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isObstacleApproaching = false;
          _obstacleDistance = 200.0;
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Impact Effect System Demo'),
        backgroundColor: Colors.grey[900],
      ),
      body: Stack(
        children: [
          // メインゲーム画面
          CustomPaint(
            painter: ImpactEffectPainter(_impactSystem, _particleEngine),
            size: Size.infinite,
          ),
          
          // UI オーバーレイ
          _buildUIOverlay(),
          
          // コントロールパネル
          _buildControlPanel(),
        ],
      ),
    );
  }
  
  Widget _buildUIOverlay() {
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // スコア表示
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.cyan.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Score: $_score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Combo: $_combo',
                  style: TextStyle(
                    color: _getComboColor(_combo),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // スローモーション状態表示
          if (_impactSystem.isSlowMotionActive)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.slow_motion_video, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Slow Motion: ${(_impactSystem.slowMotionFactor * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          
          // 障害物警告
          if (_isObstacleApproaching)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Obstacle: ${_obstacleDistance.toInt()}m',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildControlPanel() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Manual Controls',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // ボタン行1
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  'Score +500',
                  Colors.cyan,
                  () => _impactSystem.triggerScoreExplosion(
                    const Offset(200, 300),
                    500,
                    color: Colors.cyan,
                  ),
                ),
                _buildControlButton(
                  'Combo',
                  Colors.green,
                  _triggerComboEffect,
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // ボタン行2
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  'Slow Motion',
                  Colors.blue,
                  _triggerSlowMotionEffect,
                ),
                _buildControlButton(
                  'Danger!',
                  Colors.red,
                  _triggerDangerEffect,
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // リセットボタン
            _buildControlButton(
              'Reset All',
              Colors.grey,
              () {
                setState(() {
                  _score = 0;
                  _combo = 0;
                  _isObstacleApproaching = false;
                  _obstacleDistance = 200.0;
                });
                _impactSystem.clear();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildControlButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Color _getComboColor(int combo) {
    if (combo < 3) return Colors.cyan;
    if (combo < 5) return Colors.green;
    if (combo < 8) return Colors.orange;
    if (combo < 12) return Colors.red;
    return Colors.purple;
  }
  
  @override
  void dispose() {
    _impactSystem.clear();
    super.dispose();
  }
}

/// インパクトエフェクト描画用カスタムペインター
class ImpactEffectPainter extends CustomPainter {
  final ImpactEffectSystem impactSystem;
  final ParticleEngine particleEngine;
  
  ImpactEffectPainter(this.impactSystem, this.particleEngine);
  
  @override
  void paint(Canvas canvas, Size size) {
    // 背景グラデーション
    final backgroundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0F0F23),
          Color(0xFF1A1A2E),
          Color(0xFF16213E),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);
    
    // パーティクルエンジン描画
    particleEngine.render(canvas, size);
    
    // インパクトエフェクト描画
    impactSystem.render(canvas, size);
    
    // デモ用の装飾要素
    _drawDecorations(canvas, size);
  }
  
  void _drawDecorations(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    // 中央の円
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      100,
      paint,
    );
    
    // 角の装飾
    final cornerSize = 30.0;
    paint.strokeWidth = 3.0;
    
    // 左上
    canvas.drawLine(const Offset(20, 20), Offset(20 + cornerSize, 20), paint);
    canvas.drawLine(const Offset(20, 20), Offset(20, 20 + cornerSize), paint);
    
    // 右上
    canvas.drawLine(Offset(size.width - 20, 20), Offset(size.width - 20 - cornerSize, 20), paint);
    canvas.drawLine(Offset(size.width - 20, 20), Offset(size.width - 20, 20 + cornerSize), paint);
    
    // 左下
    canvas.drawLine(Offset(20, size.height - 20), Offset(20 + cornerSize, size.height - 20), paint);
    canvas.drawLine(Offset(20, size.height - 20), Offset(20, size.height - 20 - cornerSize), paint);
    
    // 右下
    canvas.drawLine(Offset(size.width - 20, size.height - 20), Offset(size.width - 20 - cornerSize, size.height - 20), paint);
    canvas.drawLine(Offset(size.width - 20, size.height - 20), Offset(size.width - 20, size.height - 20 + cornerSize), paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}