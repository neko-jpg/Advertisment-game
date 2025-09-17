import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';

void main() {
  runApp(const QuickDrawDashGame());
}

class QuickDrawDashGame extends StatelessWidget {
  const QuickDrawDashGame({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quick Draw Dash - 描いて走る冒険ゲーム',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // ゲーム状態
  GameState _gameState = GameState.menu;
  int _score = 0;
  int _coins = 0;
  int _lives = 3;
  double _speed = 2.0;
  
  // プレイヤー
  Offset _playerPosition = const Offset(100, 300);
  bool _isPlayerOnLine = false;
  
  // 描画システム
  final List<DrawnLine> _drawnLines = [];
  final List<Offset> _currentLine = [];
  bool _isDrawing = false;
  
  // ゲーム要素
  final List<Obstacle> _obstacles = [];
  final List<Coin> _gameCoins = [];
  
  // タイマー
  Timer? _gameTimer;
  Timer? _spawnTimer;
  
  @override
  void initState() {
    super.initState();
  }
  
  void _startGame() {
    print('ゲーム開始ボタンが押されました！'); // デバッグ用
    setState(() {
      _gameState = GameState.playing;
      _score = 0;
      _coins = 0;
      _lives = 3;
      _speed = 2.0;
      _playerPosition = const Offset(100, 300);
      _drawnLines.clear();
      _obstacles.clear();
      _gameCoins.clear();
    });
    
    // ゲームループ開始
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _updateGame();
    });
    
    // 要素スポーンタイマー
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 2000), (timer) {
      _spawnGameElements();
    });
    
    HapticFeedback.lightImpact();
  }
  
  void _updateGame() {
    if (_gameState != GameState.playing) return;
    
    setState(() {
      // プレイヤー更新
      _updatePlayer();
      
      // 障害物更新
      _updateObstacles();
      
      // コイン更新
      _updateCoins();
      
      // 衝突判定
      _checkCollisions();
      
      // スコア更新
      _score += 1;
    });
  }
  
  void _updatePlayer() {
    // 重力適用
    if (!_isPlayerOnLine) {
      _playerPosition = Offset(
        _playerPosition.dx,
        _playerPosition.dy + 3,
      );
    }
    
    // 描いた線との衝突判定
    _isPlayerOnLine = false;
    for (final line in _drawnLines) {
      if (_isPlayerOnDrawnLine(line)) {
        _isPlayerOnLine = true;
        break;
      }
    }
    
    // 画面外チェック
    if (_playerPosition.dy > 600) {
      _gameOver();
    }
  }
  
  bool _isPlayerOnDrawnLine(DrawnLine line) {
    const playerRadius = 15.0;
    
    for (int i = 0; i < line.points.length - 1; i++) {
      final p1 = line.points[i];
      final p2 = line.points[i + 1];
      
      final distance = _distanceToLineSegment(_playerPosition, p1, p2);
      if (distance < playerRadius) {
        return true;
      }
    }
    return false;
  }
  
  double _distanceToLineSegment(Offset point, Offset lineStart, Offset lineEnd) {
    final A = point.dx - lineStart.dx;
    final B = point.dy - lineStart.dy;
    final C = lineEnd.dx - lineStart.dx;
    final D = lineEnd.dy - lineStart.dy;
    
    final dot = A * C + B * D;
    final lenSq = C * C + D * D;
    
    if (lenSq == 0) return math.sqrt(A * A + B * B);
    
    final param = dot / lenSq;
    
    late double xx, yy;
    
    if (param < 0) {
      xx = lineStart.dx;
      yy = lineStart.dy;
    } else if (param > 1) {
      xx = lineEnd.dx;
      yy = lineEnd.dy;
    } else {
      xx = lineStart.dx + param * C;
      yy = lineStart.dy + param * D;
    }
    
    final dx = point.dx - xx;
    final dy = point.dy - yy;
    return math.sqrt(dx * dx + dy * dy);
  }  
  void
 _updateObstacles() {
    _obstacles.removeWhere((obstacle) {
      obstacle.position = Offset(
        obstacle.position.dx - _speed,
        obstacle.position.dy,
      );
      return obstacle.position.dx < -50;
    });
  }
  
  void _updateCoins() {
    _gameCoins.removeWhere((coin) {
      coin.position = Offset(
        coin.position.dx - _speed,
        coin.position.dy,
      );
      return coin.position.dx < -30;
    });
  }
  
  void _checkCollisions() {
    const playerRadius = 15.0;
    
    // 障害物との衝突
    for (final obstacle in _obstacles) {
      final distance = (obstacle.position - _playerPosition).distance;
      if (distance < playerRadius + obstacle.radius) {
        _gameOver();
        return;
      }
    }
    
    // コインとの衝突
    _gameCoins.removeWhere((coin) {
      final distance = (coin.position - _playerPosition).distance;
      if (distance < playerRadius + 15) {
        _collectCoin();
        return true;
      }
      return false;
    });
  }
  
  void _spawnGameElements() {
    final random = math.Random();
    
    // 障害物スポーン
    if (random.nextDouble() < 0.7) {
      _obstacles.add(Obstacle(
        position: Offset(800, 200 + random.nextDouble() * 300),
        radius: 20 + random.nextDouble() * 10,
      ));
    }
    
    // コインスポーン
    if (random.nextDouble() < 0.5) {
      _gameCoins.add(Coin(
        position: Offset(800, 150 + random.nextDouble() * 400),
      ));
    }
  }
  
  void _collectCoin() {
    setState(() {
      _coins++;
      _score += 50;
    });
    HapticFeedback.selectionClick();
  }
  
  void _gameOver() {
    setState(() {
      _gameState = GameState.gameOver;
    });
    
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
  }
  
  void _jump() {
    setState(() {
      _playerPosition = Offset(
        _playerPosition.dx,
        _playerPosition.dy - 100,
      );
    });
    HapticFeedback.lightImpact();
  }
  
  void _onPanStart(DragStartDetails details) {
    if (_gameState != GameState.playing) return;
    
    setState(() {
      _isDrawing = true;
      _currentLine.clear();
      _currentLine.add(details.localPosition);
    });
  }
  
  void _onPanUpdate(DragUpdateDetails details) {
    if (_gameState != GameState.playing || !_isDrawing) return;
    
    setState(() {
      _currentLine.add(details.localPosition);
    });
  }
  
  void _onPanEnd(DragEndDetails details) {
    if (_gameState != GameState.playing || !_isDrawing) return;
    
    setState(() {
      _isDrawing = false;
      if (_currentLine.length > 1) {
        _drawnLines.add(DrawnLine(
          points: List.from(_currentLine),
          color: Colors.cyan,
          width: 5.0,
        ));
        
        // 古い線を削除（最大10本まで）
        if (_drawnLines.length > 10) {
          _drawnLines.removeAt(0);
        }
      }
      _currentLine.clear();
    });
    
    HapticFeedback.selectionClick();
  }
  
  @override
  void dispose() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F23), Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: Stack(
          children: [
            // ゲーム画面
            if (_gameState == GameState.playing) ...[
              // ゲームエリア
              GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                onTap: _jump,
                child: CustomPaint(
                  painter: GamePainter(
                    drawnLines: _drawnLines,
                    currentLine: _currentLine,
                    isDrawing: _isDrawing,
                    playerPosition: _playerPosition,
                    obstacles: _obstacles,
                    coins: _gameCoins,
                  ),
                  size: Size.infinite,
                ),
              ),
              
              // UI オーバーレイ
              _buildGameUI(),
            ],
            
            // メニュー画面
            if (_gameState == GameState.menu) _buildMenuScreen(),
            
            // ゲームオーバー画面
            if (_gameState == GameState.gameOver) _buildGameOverScreen(),
          ],
        ),
      ),
    );
  } 
 
  Widget _buildGameUI() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 上部UI
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // スコア
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'スコア: $_score',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                // ライフ
                Row(
                  children: List.generate(_lives, (index) => 
                    const Icon(Icons.favorite, color: Colors.red, size: 24)
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            // 下部UI
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // コイン
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        '$_coins',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMenuScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F0F23), Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ロゴ
            const Icon(
              Icons.brush,
              size: 120,
              color: Colors.cyan,
            ),
            const SizedBox(height: 20),
            
            // タイトル
            const Text(
              'Quick Draw Dash',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(2, 2),
                    blurRadius: 4,
                    color: Colors.cyan,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),
            const Text(
              '描いて走る冒険ゲーム',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white70,
              ),
            ),
            
            const SizedBox(height: 60),
            
            // 開始ボタン
            ElevatedButton(
              onPressed: () {
                print('ボタンがタップされました！'); // デバッグ用
                _startGame();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'ゲーム開始',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 説明
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                '画面をタップしてジャンプ\n指で線を描いて道を作ろう！',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white60,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGameOverScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F0F23), Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ゲームオーバーテキスト
            const Text(
              'ゲームオーバー',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // 最終スコア
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    '最終スコア: $_score',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '獲得コイン: $_coins',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // ボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child: const Text('もう一度'),
                ),
                
                const SizedBox(width: 20),
                
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _gameState = GameState.menu;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child: const Text('メニュー'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}// ゲーム状態

enum GameState { menu, playing, gameOver }

// 描いた線のクラス
class DrawnLine {
  final List<Offset> points;
  final Color color;
  final double width;
  
  DrawnLine({
    required this.points,
    required this.color,
    required this.width,
  });
}

// 障害物クラス
class Obstacle {
  Offset position;
  final double radius;
  
  Obstacle({
    required this.position,
    required this.radius,
  });
}

// コインクラス
class Coin {
  Offset position;
  
  Coin({required this.position});
}

// ゲーム描画クラス
class GamePainter extends CustomPainter {
  final List<DrawnLine> drawnLines;
  final List<Offset> currentLine;
  final bool isDrawing;
  final Offset playerPosition;
  final List<Obstacle> obstacles;
  final List<Coin> coins;
  
  GamePainter({
    required this.drawnLines,
    required this.currentLine,
    required this.isDrawing,
    required this.playerPosition,
    required this.obstacles,
    required this.coins,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // 描いた線を描画
    for (final line in drawnLines) {
      _drawLine(canvas, line);
    }
    
    // 現在描いている線を描画
    if (isDrawing && currentLine.length > 1) {
      _drawCurrentLine(canvas);
    }
    
    // プレイヤーを描画
    _drawPlayer(canvas);
    
    // 障害物を描画
    for (final obstacle in obstacles) {
      _drawObstacle(canvas, obstacle);
    }
    
    // コインを描画
    for (final coin in coins) {
      _drawCoin(canvas, coin);
    }
  }
  
  void _drawLine(Canvas canvas, DrawnLine line) {
    final paint = Paint()
      ..color = line.color
      ..strokeWidth = line.width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    if (line.points.isNotEmpty) {
      path.moveTo(line.points.first.dx, line.points.first.dy);
      for (int i = 1; i < line.points.length; i++) {
        path.lineTo(line.points[i].dx, line.points[i].dy);
      }
    }
    
    canvas.drawPath(path, paint);
    
    // グロー効果
    final glowPaint = Paint()
      ..color = line.color.withOpacity(0.3)
      ..strokeWidth = line.width + 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawPath(path, glowPaint);
  }
  
  void _drawCurrentLine(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.7)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    path.moveTo(currentLine.first.dx, currentLine.first.dy);
    for (int i = 1; i < currentLine.length; i++) {
      path.lineTo(currentLine[i].dx, currentLine[i].dy);
    }
    
    canvas.drawPath(path, paint);
  }
  
  void _drawPlayer(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    // プレイヤー本体
    canvas.drawCircle(playerPosition, 15, paint);
    
    // 目
    final eyePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(playerPosition.dx - 5, playerPosition.dy - 5),
      3,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(playerPosition.dx + 5, playerPosition.dy - 5),
      3,
      eyePaint,
    );
    
    // グロー効果
    final glowPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.5)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    
    canvas.drawCircle(playerPosition, 18, glowPaint);
  }
  
  void _drawObstacle(Canvas canvas, Obstacle obstacle) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(obstacle.position, obstacle.radius, paint);
    
    // 危険マーク
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '!',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        obstacle.position.dx - textPainter.width / 2,
        obstacle.position.dy - textPainter.height / 2,
      ),
    );
  }
  
  void _drawCoin(Canvas canvas, Coin coin) {
    final paint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(coin.position, 15, paint);
    
    // コインマーク
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '¥',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        coin.position.dx - textPainter.width / 2,
        coin.position.dy - textPainter.height / 2,
      ),
    );
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}