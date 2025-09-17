import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'shape_recognition_engine.dart';
import 'shape_actions.dart';
import 'shape_feedback_system.dart';
import '../effects/particle_engine.dart';

/// 形状認識システムの統合管理クラス
class ShapeRecognitionManager {
  final ShapeRecognitionEngine _recognitionEngine;
  final ShapeActionManager _actionManager;
  final ShapeFeedbackSystem _feedbackSystem;
  
  // 認識設定
  bool _isEnabled = true;
  double _recognitionSensitivity = 0.7;
  bool _realTimeRecognition = true;
  
  // 描画追跡
  final List<Offset> _currentDrawing = [];
  Timer? _recognitionTimer;
  RecognizedShape? _lastRecognizedShape;
  
  // イベントストリーム
  final StreamController<ShapeRecognitionEvent> _eventController = StreamController.broadcast();
  late final StreamSubscription _actionSubscription;
  late final StreamSubscription _feedbackSubscription;

  ShapeRecognitionManager({
    required ParticleEngine particleEngine,
  }) : _recognitionEngine = ShapeRecognitionEngine(),
       _actionManager = ShapeActionManager(),
       _feedbackSystem = ShapeFeedbackSystem(particleEngine) {
    
    _setupEventListeners();
  }

  /// 認識イベントのストリーム
  Stream<ShapeRecognitionEvent> get recognitionEvents => _eventController.stream;

  /// アクションマネージャーへのアクセス
  ShapeActionManager get actionManager => _actionManager;

  /// フィードバックシステムへのアクセス
  ShapeFeedbackSystem get feedbackSystem => _feedbackSystem;

  /// 認識システムの有効/無効
  bool get isEnabled => _isEnabled;
  set isEnabled(bool value) {
    _isEnabled = value;
    if (!value) {
      _clearCurrentDrawing();
    }
  }

  /// 認識感度の設定（0.0-1.0）
  double get recognitionSensitivity => _recognitionSensitivity;
  set recognitionSensitivity(double value) {
    _recognitionSensitivity = value.clamp(0.0, 1.0);
  }

  /// リアルタイム認識の有効/無効
  bool get realTimeRecognition => _realTimeRecognition;
  set realTimeRecognition(bool value) {
    _realTimeRecognition = value;
    if (!value) {
      _recognitionTimer?.cancel();
    }
  }

  /// 描画開始
  void startDrawing(Offset point) {
    if (!_isEnabled) return;
    
    _clearCurrentDrawing();
    _currentDrawing.add(point);
    
    _eventController.add(ShapeRecognitionEvent(
      type: ShapeRecognitionEventType.drawingStarted,
      position: point,
    ));
  }

  /// 描画点の追加
  void addDrawingPoint(Offset point) {
    if (!_isEnabled || _currentDrawing.isEmpty) return;
    
    // 重複点を避ける
    if (_currentDrawing.isNotEmpty) {
      final lastPoint = _currentDrawing.last;
      final distance = math.sqrt(
        math.pow(point.dx - lastPoint.dx, 2) + math.pow(point.dy - lastPoint.dy, 2)
      );
      
      if (distance < 5.0) return; // 5ピクセル未満の移動は無視
    }
    
    _currentDrawing.add(point);
    
    // リアルタイム認識
    if (_realTimeRecognition && _currentDrawing.length >= 10) {
      _scheduleRecognition();
    }
    
    _eventController.add(ShapeRecognitionEvent(
      type: ShapeRecognitionEventType.drawingUpdated,
      position: point,
      currentPoints: List.from(_currentDrawing),
    ));
  }

  /// 描画終了
  Future<void> endDrawing() async {
    if (!_isEnabled || _currentDrawing.isEmpty) return;
    
    _recognitionTimer?.cancel();
    
    _eventController.add(ShapeRecognitionEvent(
      type: ShapeRecognitionEventType.drawingEnded,
      currentPoints: List.from(_currentDrawing),
    ));
    
    // 最終認識を実行
    await _performRecognition();
  }

  /// 描画をクリア
  void _clearCurrentDrawing() {
    _currentDrawing.clear();
    _recognitionTimer?.cancel();
    _lastRecognizedShape = null;
  }

  /// 認識をスケジュール
  void _scheduleRecognition() {
    _recognitionTimer?.cancel();
    
    _recognitionTimer = Timer(const Duration(milliseconds: 300), () {
      _performRecognition();
    });
  }

  /// 認識を実行
  Future<void> _performRecognition() async {
    if (_currentDrawing.length < 10) {
      await _feedbackSystem.triggerFailureFeedback(
        _currentDrawing, 
        '描画が短すぎます'
      );
      return;
    }

    // 形状認識を実行
    final recognizedShape = _recognitionEngine.recognizeShape(_currentDrawing);
    
    if (recognizedShape == null) {
      await _feedbackSystem.triggerFailureFeedback(
        _currentDrawing, 
        '認識できる形状がありません'
      );
      
      _eventController.add(ShapeRecognitionEvent(
        type: ShapeRecognitionEventType.recognitionFailed,
        currentPoints: List.from(_currentDrawing),
        failureReason: '認識できる形状がありません',
      ));
      return;
    }

    // 感度チェック
    if (recognizedShape.confidence < _recognitionSensitivity) {
      await _feedbackSystem.triggerFailureFeedback(
        _currentDrawing, 
        '形状の精度が不十分です (${(recognizedShape.confidence * 100).toStringAsFixed(0)}%)'
      );
      
      _eventController.add(ShapeRecognitionEvent(
        type: ShapeRecognitionEventType.recognitionFailed,
        currentPoints: List.from(_currentDrawing),
        recognizedShape: recognizedShape,
        failureReason: '精度不足',
      ));
      return;
    }

    _lastRecognizedShape = recognizedShape;

    // アクション実行
    final actionResult = await _actionManager.executeAction(recognizedShape);
    
    if (actionResult.success) {
      // 成功フィードバック
      await _feedbackSystem.triggerSuccessFeedback(recognizedShape, actionResult);
      
      _eventController.add(ShapeRecognitionEvent(
        type: ShapeRecognitionEventType.recognitionSucceeded,
        currentPoints: List.from(_currentDrawing),
        recognizedShape: recognizedShape,
        actionResult: actionResult,
      ));
    } else {
      // アクション失敗フィードバック
      await _feedbackSystem.triggerFailureFeedback(
        _currentDrawing, 
        actionResult.message
      );
      
      _eventController.add(ShapeRecognitionEvent(
        type: ShapeRecognitionEventType.actionFailed,
        currentPoints: List.from(_currentDrawing),
        recognizedShape: recognizedShape,
        actionResult: actionResult,
      ));
    }
  }

  /// 進行中の認識フィードバック
  void _triggerProgressFeedback() {
    if (_currentDrawing.length < 5) return;
    
    // 暫定的な認識を試行
    final tempShape = _recognitionEngine.recognizeShape(_currentDrawing);
    final confidence = tempShape?.confidence ?? 0.0;
    
    _feedbackSystem.triggerProgressFeedback(_currentDrawing, confidence);
  }

  /// イベントリスナーの設定
  void _setupEventListeners() {
    // アクションイベントの監視
    _actionSubscription = _actionManager.actionEvents.listen((event) {
      _eventController.add(ShapeRecognitionEvent(
        type: event.type == ShapeActionEventType.activated 
            ? ShapeRecognitionEventType.actionActivated
            : ShapeRecognitionEventType.actionDeactivated,
        recognizedShape: _lastRecognizedShape,
        actionEvent: event,
      ));
    });

    // フィードバックイベントの監視
    _feedbackSubscription = _feedbackSystem.feedbackEvents.listen((event) {
      _eventController.add(ShapeRecognitionEvent(
        type: ShapeRecognitionEventType.feedbackTriggered,
        position: event.position,
        feedbackEvent: event,
      ));
    });
  }

  /// 現在の描画状態を取得
  ShapeRecognitionState getCurrentState() {
    return ShapeRecognitionState(
      isDrawing: _currentDrawing.isNotEmpty,
      currentPoints: List.from(_currentDrawing),
      lastRecognizedShape: _lastRecognizedShape,
      isEnabled: _isEnabled,
      sensitivity: _recognitionSensitivity,
      realTimeEnabled: _realTimeRecognition,
    );
  }

  /// 統計情報を取得
  ShapeRecognitionStats getStats() {
    // 実装では実際の統計を追跡
    return const ShapeRecognitionStats(
      totalRecognitions: 0,
      successfulRecognitions: 0,
      failedRecognitions: 0,
      averageConfidence: 0.0,
      shapeTypeStats: {},
    );
  }

  /// 設定をリセット
  void resetSettings() {
    _isEnabled = true;
    _recognitionSensitivity = 0.7;
    _realTimeRecognition = true;
    _clearCurrentDrawing();
  }

  /// リソースのクリーンアップ
  void dispose() {
    _recognitionTimer?.cancel();
    _actionSubscription.cancel();
    _feedbackSubscription.cancel();
    _actionManager.dispose();
    _feedbackSystem.dispose();
    _eventController.close();
  }
}

/// 形状認識イベントの種類
enum ShapeRecognitionEventType {
  drawingStarted,        // 描画開始
  drawingUpdated,        // 描画更新
  drawingEnded,          // 描画終了
  recognitionSucceeded,  // 認識成功
  recognitionFailed,     // 認識失敗
  actionActivated,       // アクション発動
  actionDeactivated,     // アクション終了
  actionFailed,          // アクション失敗
  feedbackTriggered,     // フィードバック発生
}

/// 形状認識イベント
class ShapeRecognitionEvent {
  final ShapeRecognitionEventType type;
  final Offset? position;
  final List<Offset>? currentPoints;
  final RecognizedShape? recognizedShape;
  final ShapeActionResult? actionResult;
  final ShapeActionEvent? actionEvent;
  final ShapeFeedbackEvent? feedbackEvent;
  final String? failureReason;

  const ShapeRecognitionEvent({
    required this.type,
    this.position,
    this.currentPoints,
    this.recognizedShape,
    this.actionResult,
    this.actionEvent,
    this.feedbackEvent,
    this.failureReason,
  });
}

/// 形状認識の現在状態
class ShapeRecognitionState {
  final bool isDrawing;
  final List<Offset> currentPoints;
  final RecognizedShape? lastRecognizedShape;
  final bool isEnabled;
  final double sensitivity;
  final bool realTimeEnabled;

  const ShapeRecognitionState({
    required this.isDrawing,
    required this.currentPoints,
    required this.lastRecognizedShape,
    required this.isEnabled,
    required this.sensitivity,
    required this.realTimeEnabled,
  });
}

/// 形状認識の統計情報
class ShapeRecognitionStats {
  final int totalRecognitions;
  final int successfulRecognitions;
  final int failedRecognitions;
  final double averageConfidence;
  final Map<ShapeType, int> shapeTypeStats;

  const ShapeRecognitionStats({
    required this.totalRecognitions,
    required this.successfulRecognitions,
    required this.failedRecognitions,
    required this.averageConfidence,
    required this.shapeTypeStats,
  });

  double get successRate => totalRecognitions > 0 
      ? successfulRecognitions / totalRecognitions 
      : 0.0;
}