import 'package:flutter/material.dart';
import 'camera_integration.dart';
import 'camera_effects.dart';

/// カメラシステム統合例 - 既存ゲームへの統合方法
class CameraIntegrationExample extends StatefulWidget {
  const CameraIntegrationExample({super.key});
  
  @override
  State<CameraIntegrationExample> createState() => _CameraIntegrationExampleState();
}

class _CameraIntegrationExampleState extends State<CameraIntegrationExample>
    with TickerProviderStateMixin {
  late CameraIntegration _cameraIntegration;
  
  // ゲーム状態（例）
  Offset _playerPosition = const Offset(400, 300);
  Offset _playerVelocity = Offset.zero;
  final List<Offset> _obstacles = [];
  final List<Offset> _coins = [];
  int _score = 0;
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeGameElements();
  }
  
  void _initializeCamera() {
    _cameraIntegration = CameraIntegration();
    
    // カメラ初期化
    _cameraIntegration.initialize(
      initialPosition: _playerPosition,
      bounds: const Rect.fromLTWH(0, 0, 2000, 1200), // ゲームワールドサイズ
      safeArea: const EdgeInsets.all(100), // 画面端からの安全距離
    );
    
    // カメラ追従設定
    _cameraIntegration.cameraSystem.configureFollow(
      followSpeed: 0.08, // 追従速度（0.0-1.0）
      maxFollowDistance: 150.0, // 最大追従距離
      predictionFactor: 0.4, // 予測移動係数
      dampingFactor: 0.85, // 慣性減衰係数
    );
  }
  
  void _initializeGameElements() {
    // 障害物配置
    for (int i = 0; i < 20; i++) {
      _obstacles.add(Offset(
        200.0 + i * 100.0,
        200.0 + (i % 3) * 150.0,
      ));
    }
    
    // コイン配置
    for (int i = 0; i < 15; i++) {
      _coins.add(Offset(
        300.0 + i * 120.0,
        150.0 + (i % 4) * 100.0,
      ));
    }
  }
  
  void _updateGame() {
    // プレイヤー位置更新
    setState(() {
      _playerPosition = Offset(
        _playerPosition.dx + _playerVelocity.dx,
        _playerPosition.dy + _playerVelocity.dy,
      );
      
      // カメラにプレイヤー位置を通知
      _cameraIntegration.followPlayer(_playerPosition, velocity: _playerVelocity);
      
      // 衝突判定とエフェクト
      _checkCollisions();
    });
  }
  
  void _checkCollisions() {
    // 障害物との衝突
    _obstacles.removeWhere((obstacle) {
      if ((_playerPosition - obstacle).distance < 30) {
        // 衝突エフェクト
        _cameraIntegration.applyPreset(CameraPreset.mediumShake);
        return true;
      }
      return false;
    });
    
    // コインとの衝突
    _coins.removeWhere((coin) {
      if ((_playerPosition - coin).distance < 25) {
        // コイン獲得エフェクト
        _cameraIntegration.applyPreset(CameraPreset.punchInZoom);
        _score += 10;
        return true;
      }
      return false;
    });
  }
  
  void _movePlayer(Offset direction) {
    _playerVelocity = direction * 3.0;
    
    // 移動開始時の軽いエフェクト
    if (direction != Offset.zero) {
      _cameraIntegration.applyPreset(CameraPreset.lightShake);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CameraIntegratedWidget(
        cameraIntegration: _cameraIntegration,
        enableDebugOverlay: true, // デバッグ情報表示
        child: Stack(
          children: [
            // 背景
            _buildBackground(),
            
            // ゲーム要素
            _buildGameElements(),
            
            // UI（カメラの影響を受けない）
            _buildUI(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBackground() {
    return Container(
      width: 2000,
      height: 1200,
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
      child: CustomPaint(
        painter: GridPainter(),
      ),
    );
  }
  
  Widget _buildGameElements() {
    return Stack(
      children: [
        // プレイヤー
        Positioned(
          left: _playerPosition.dx - 15,
          top: _playerPosition.dy - 15,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.cyan,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
        
        // 障害物
        ...._obstacles.map((obstacle) => Positioned(
          left: obstacle.dx - 15,
          top: obstacle.dy - 15,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 5,
                ),
              ],
            ),
          ),
        )),
        
        // コイン
        ...._coins.map((coin) => Positioned(
          left: coin.dx - 12,
          top: coin.dy - 12,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.amber,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.4),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }
  
  Widget _buildUI() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // スコア表示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Score: $_score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 操作ボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton('↑', () => _movePlayer(const Offset(0, -1))),
                _buildControlButton('↓', () => _movePlayer(const Offset(0, 1))),
                _buildControlButton('←', () => _movePlayer(const Offset(-1, 0))),
                _buildControlButton('→', () => _movePlayer(const Offset(1, 0))),
                _buildControlButton('Stop', () => _movePlayer(Offset.zero)),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // エフェクトテストボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildEffectButton('Shake', () => 
                  _cameraIntegration.applyPreset(CameraPreset.heavyShake)),
                _buildEffectButton('Zoom', () => 
                  _cameraIntegration.applyPreset(CameraPreset.slowMotionZoom)),
                _buildEffectButton('Impact', () => 
                  _cameraIntegration.applyPreset(CameraPreset.impactCombo)),
                _buildEffectButton('Boss', () => 
                  _cameraIntegration.applyPreset(CameraPreset.bossEntrance)),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildControlButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: () {
        onPressed();
        _updateGame();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.cyan.withOpacity(0.8),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label),
    );
  }
  
  Widget _buildEffectButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple.withOpacity(0.8),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

/// グリッド背景描画
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;
    
    // 縦線
    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
    
    // 横線
    for (double y = 0; y < size.height; y += 50) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 既存ゲームへの統合ガイド
class CameraIntegrationGuide {
  /// simple_main.dartへの統合手順
  static String get integrationSteps => '''
# カメラシステム統合手順

## 1. インポート追加
```dart
import 'game/camera/camera_integration.dart';
```

## 2. GameScreenStateにカメラ追加
```dart
class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late CameraIntegration _cameraIntegration;
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
    // 既存の初期化...
  }
  
  void _initializeCamera() {
    _cameraIntegration = CameraIntegration();
    _cameraIntegration.initialize(
      initialPosition: _playerPosition,
      bounds: const Rect.fromLTWH(0, 0, 2000, 1200),
    );
  }
}
```

## 3. ゲームループでカメラ更新
```dart
void _updateGame() {
  if (_gameState != GameState.playing) return;
  
  // カメラにプレイヤー位置を通知
  _cameraIntegration.followPlayer(_playerPosition, velocity: _playerVelocity);
  
  // 既存の更新処理...
}
```

## 4. イベント時にエフェクト追加
```dart
void _collectCoin() {
  // 既存の処理...
  _cameraIntegration.applyPreset(CameraPreset.punchInZoom);
}

void _playerDied() {
  // 既存の処理...
  _cameraIntegration.applyPreset(CameraPreset.heavyShake);
}
```

## 5. buildメソッドでカメラ統合
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: CameraIntegratedWidget(
      cameraIntegration: _cameraIntegration,
      child: // 既存のゲーム画面
    ),
  );
}
```
''';
}