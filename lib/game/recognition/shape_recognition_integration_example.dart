import 'package:flutter/material.dart';
import 'dart:async';
import 'shape_recognition_manager.dart';
import 'shape_recognition_engine.dart';
import 'shape_actions.dart';
import '../effects/particle_engine.dart';

/// 形状認識システムの統合例
class ShapeRecognitionIntegrationExample extends StatefulWidget {
  const ShapeRecognitionIntegrationExample({Key? key}) : super(key: key);

  @override
  State<ShapeRecognitionIntegrationExample> createState() => _ShapeRecognitionIntegrationExampleState();
}

class _ShapeRecognitionIntegrationExampleState extends State<ShapeRecognitionIntegrationExample>
    with TickerProviderStateMixin {
  
  late ShapeRecognitionManager _recognitionManager;
  late ParticleEngine _particleEngine;
  late StreamSubscription _recognitionSubscription;
  
  // UI状態
  final List<Offset> _currentDrawing = [];
  RecognizedShape? _lastRecognizedShape;
  String _statusMessage = '形状を描いてください';
  Color _statusColor = Colors.white;
  
  // アクティブエフェクト
  final Map<ShapeType, Widget> _activeEffects = {};
  
  // 統計
  int _totalRecognitions = 0;
  int _successfulRecognitions = 0;
  final Map<ShapeType, int> _shapeStats = {};

  @override
  void initState() {
    super.initState();
    _initializeRecognitionSystem();
  }

  void _initializeRecognitionSystem() {
    // パーティクルエンジンを初期化
    _particleEngine = ParticleEngine();
    
    // 形状認識マネージャーを初期化
    _recognitionManager = ShapeRecognitionManager(
      particleEngine: _particleEngine,
    );
    
    // イベントリスナーを設定
    _recognitionSubscription = _recognitionManager.recognitionEvents.listen(_handleRecognitionEvent);
  }

  void _handleRecognitionEvent(ShapeRecognitionEvent event) {
    setState(() {
      switch (event.type) {
        case ShapeRecognitionEventType.drawingStarted:
          _currentDrawing.clear();
          _statusMessage = '描画中...';
          _statusColor = Colors.blue;
          break;
          
        case ShapeRecognitionEventType.drawingUpdated:
          if (event.currentPoints != null) {
            _currentDrawing.clear();
            _currentDrawing.addAll(event.currentPoints!);
          }
          break;
          
        case ShapeRecognitionEventType.drawingEnded:
          _statusMessage = '認識中...';
          _statusColor = Colors.orange;
          break;
          
        case ShapeRecognitionEventType.recognitionSucceeded:
          _handleSuccessfulRecognition(event);
          break;
          
        case ShapeRecognitionEventType.recognitionFailed:
          _handleFailedRecognition(event);
          break;
          
        case ShapeRecognitionEventType.actionActivated:
          _handleActionActivated(event);
          break;
          
        case ShapeRecognitionEventType.actionDeactivated:
          _handleActionDeactivated(event);
          break;
          
        case ShapeRecognitionEventType.actionFailed:
          _handleActionFailed(event);
          break;
          
        case ShapeRecognitionEventType.feedbackTriggered:
          // フィードバックイベントの処理
          break;
      }
    });
  }

  void _handleSuccessfulRecognition(ShapeRecognitionEvent event) {
    _lastRecognizedShape = event.recognizedShape;
    _totalRecognitions++;
    _successfulRecognitions++;
    
    if (event.recognizedShape != null) {
      final shapeType = event.recognizedShape!.type;
      _shapeStats[shapeType] = (_shapeStats[shapeType] ?? 0) + 1;
      
      final confidence = (event.recognizedShape!.confidence * 100).toStringAsFixed(0);
      _statusMessage = '${_getShapeNameJapanese(shapeType)} 認識成功! (${confidence}%)';
      _statusColor = Colors.green;
      
      if (event.actionResult?.success == true) {
        _statusMessage += '\n${event.actionResult!.message}';
      }
    }
  }

  void _handleFailedRecognition(ShapeRecognitionEvent event) {
    _totalRecognitions++;
    _statusMessage = event.failureReason ?? '認識に失敗しました';
    _statusColor = Colors.red;
  }

  void _handleActionActivated(ShapeRecognitionEvent event) {
    if (event.actionEvent?.shapeType != null) {
      final shapeType = event.actionEvent!.shapeType;
      _activeEffects[shapeType] = _createEffectWidget(shapeType, event.actionEvent!.effectData);
      
      // 効果の自動削除タイマー
      final duration = _getEffectDuration(shapeType);
      Timer(duration, () {
        setState(() {
          _activeEffects.remove(shapeType);
        });
      });
    }
  }

  void _handleActionDeactivated(ShapeRecognitionEvent event) {
    if (event.actionEvent?.shapeType != null) {
      setState(() {
        _activeEffects.remove(event.actionEvent!.shapeType);
      });
    }
  }

  void _handleActionFailed(ShapeRecognitionEvent event) {
    if (event.actionResult != null) {
      _statusMessage = 'アクション失敗: ${event.actionResult!.message}';
      _statusColor = Colors.orange;
    }
  }

  Widget _createEffectWidget(ShapeType shapeType, Map<String, dynamic>? effectData) {
    switch (shapeType) {
      case ShapeType.circle:
        return _createShieldEffect(effectData);
      case ShapeType.triangle:
        return _createJumpPadEffect(effectData);
      case ShapeType.wave:
        return _createSpeedBoostEffect(effectData);
      case ShapeType.spiral:
        return _createTornadoEffect(effectData);
      case ShapeType.unknown:
        return const SizedBox.shrink();
    }
  }

  Widget _createShieldEffect(Map<String, dynamic>? data) {
    final radius = data?['radius'] ?? 50.0;
    final strength = data?['strength'] ?? 100;
    
    return Positioned(
      left: (data?['position']?.dx ?? 0) - radius,
      top: (data?['position']?.dy ?? 0) - radius,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.cyan.withAlpha(150),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyan.withAlpha(100),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            'シールド\n$strength%',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.cyan,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _createJumpPadEffect(Map<String, dynamic>? data) {
    final size = data?['size'] ?? 40.0;
    final power = data?['power'] ?? 100;
    
    return Positioned(
      left: (data?['position']?.dx ?? 0) - size / 2,
      top: (data?['position']?.dy ?? 0) - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.orange.withAlpha(150),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withAlpha(100),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Text(
            'ジャンプ\n$power%',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _createSpeedBoostEffect(Map<String, dynamic>? data) {
    final multiplier = data?['multiplier'] ?? 1.5;
    
    return Positioned(
      left: (data?['position']?.dx ?? 0) - 30,
      top: (data?['position']?.dy ?? 0) - 15,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withAlpha(150),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withAlpha(100),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Text(
          'スピード ${multiplier.toStringAsFixed(1)}x',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _createTornadoEffect(Map<String, dynamic>? data) {
    final radius = data?['radius'] ?? 60.0;
    
    return Positioned(
      left: (data?['position']?.dx ?? 0) - radius,
      top: (data?['position']?.dy ?? 0) - radius,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.purple.withAlpha(50),
              Colors.purple.withAlpha(150),
              Colors.purple.withAlpha(50),
            ],
          ),
        ),
        child: const Center(
          child: Text(
            '竜巻',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Duration _getEffectDuration(ShapeType shapeType) {
    switch (shapeType) {
      case ShapeType.circle:
        return const Duration(seconds: 5);
      case ShapeType.triangle:
        return const Duration(seconds: 3);
      case ShapeType.wave:
        return const Duration(seconds: 4);
      case ShapeType.spiral:
        return const Duration(seconds: 6);
      case ShapeType.unknown:
        return Duration.zero;
    }
  }

  String _getShapeNameJapanese(ShapeType shapeType) {
    switch (shapeType) {
      case ShapeType.circle:
        return '円形';
      case ShapeType.triangle:
        return '三角形';
      case ShapeType.wave:
        return '波形';
      case ShapeType.spiral:
        return '螺旋';
      case ShapeType.unknown:
        return '不明';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('形状認識システム'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: Icon(_recognitionManager.isEnabled ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _recognitionManager.isEnabled = !_recognitionManager.isEnabled;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // メイン描画エリア
          GestureDetector(
            onPanStart: (details) {
              _recognitionManager.startDrawing(details.localPosition);
            },
            onPanUpdate: (details) {
              _recognitionManager.addDrawingPoint(details.localPosition);
            },
            onPanEnd: (details) {
              _recognitionManager.endDrawing();
            },
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
              child: CustomPaint(
                painter: DrawingPainter(_currentDrawing, _lastRecognizedShape),
              ),
            ),
          ),
          
          // アクティブエフェクト
          ..._activeEffects.values,
          
          // パーティクルエンジン
          Positioned.fill(
            child: CustomPaint(
              painter: ParticlePainter(_particleEngine),
            ),
          ),
          
          // UI オーバーレイ
          _buildUIOverlay(),
        ],
      ),
    );
  }

  Widget _buildUIOverlay() {
    return Column(
      children: [
        // ステータス表示
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.black.withAlpha(150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _statusMessage,
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '成功率: ${_totalRecognitions > 0 ? (_successfulRecognitions / _totalRecognitions * 100).toStringAsFixed(1) : 0}% '
                '(${_successfulRecognitions}/${_totalRecognitions})',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        
        const Spacer(),
        
        // 設定パネル
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.black.withAlpha(150),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('感度: ', style: TextStyle(color: Colors.white)),
                  Expanded(
                    child: Slider(
                      value: _recognitionManager.recognitionSensitivity,
                      onChanged: (value) {
                        setState(() {
                          _recognitionManager.recognitionSensitivity = value;
                        });
                      },
                      min: 0.3,
                      max: 1.0,
                      divisions: 7,
                      label: '${(_recognitionManager.recognitionSensitivity * 100).round()}%',
                    ),
                  ),
                ],
              ),
              
              Row(
                children: [
                  const Text('リアルタイム認識: ', style: TextStyle(color: Colors.white)),
                  Switch(
                    value: _recognitionManager.realTimeRecognition,
                    onChanged: (value) {
                      setState(() {
                        _recognitionManager.realTimeRecognition = value;
                      });
                    },
                  ),
                ],
              ),
              
              // 形状別統計
              if (_shapeStats.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('形状別統計:', style: TextStyle(color: Colors.white, fontSize: 12)),
                Wrap(
                  children: _shapeStats.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${_getShapeNameJapanese(entry.key)}: ${entry.value}',
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _recognitionSubscription.cancel();
    _recognitionManager.dispose();
    _particleEngine.dispose();
    super.dispose();
  }
}

/// 描画とエフェクトを描画するカスタムペインター
class DrawingPainter extends CustomPainter {
  final List<Offset> points;
  final RecognizedShape? recognizedShape;

  DrawingPainter(this.points, this.recognizedShape);

  @override
  void paint(Canvas canvas, Size size) {
    // 現在の描画を描画
    if (points.length > 1) {
      final paint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      path.moveTo(points.first.dx, points.first.dy);
      
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      
      canvas.drawPath(path, paint);
    }

    // 認識された形状のハイライト
    if (recognizedShape != null) {
      final highlightPaint = Paint()
        ..color = _getShapeColor(recognizedShape!.type).withAlpha(100)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke;

      _drawShapeHighlight(canvas, recognizedShape!, highlightPaint);
    }
  }

  void _drawShapeHighlight(Canvas canvas, RecognizedShape shape, Paint paint) {
    switch (shape.type) {
      case ShapeType.circle:
        canvas.drawCircle(shape.center, shape.size / 2, paint);
        break;
      case ShapeType.triangle:
      case ShapeType.wave:
      case ShapeType.spiral:
        // 元の点列をハイライト
        if (shape.originalPoints.length > 1) {
          final path = Path();
          path.moveTo(shape.originalPoints.first.dx, shape.originalPoints.first.dy);
          for (int i = 1; i < shape.originalPoints.length; i++) {
            path.lineTo(shape.originalPoints[i].dx, shape.originalPoints[i].dy);
          }
          canvas.drawPath(path, paint);
        }
        break;
      case ShapeType.unknown:
        break;
    }
  }

  Color _getShapeColor(ShapeType shapeType) {
    switch (shapeType) {
      case ShapeType.circle:
        return Colors.cyan;
      case ShapeType.triangle:
        return Colors.orange;
      case ShapeType.wave:
        return Colors.blue;
      case ShapeType.spiral:
        return Colors.purple;
      case ShapeType.unknown:
        return Colors.grey;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// パーティクルを描画するカスタムペインター
class ParticlePainter extends CustomPainter {
  final ParticleEngine particleEngine;

  ParticlePainter(this.particleEngine);

  @override
  void paint(Canvas canvas, Size size) {
    // パーティクルエンジンの描画処理
    // 実際の実装では ParticleEngine の描画メソッドを呼び出し
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}