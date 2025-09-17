import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// レンダリング最適化システム - 60FPS維持のための描画最適化
class RenderOptimizer {
  static final RenderOptimizer _instance = RenderOptimizer._internal();
  factory RenderOptimizer() => _instance;
  RenderOptimizer._internal();

  // 最適化設定
  bool _enableObjectPooling = true;
  bool _enableFrustumCulling = true;
  bool _enableLevelOfDetail = true;
  bool _enableBatching = true;
  
  // オブジェクトプール
  final List<Paint> _paintPool = [];
  final List<Path> _pathPool = [];
  final List<Rect> _rectPool = [];
  
  // カリング用の画面境界
  Rect _screenBounds = Rect.zero;
  
  // LOD（Level of Detail）設定
  static const double _lodDistance1 = 200.0; // 高品質
  static const double _lodDistance2 = 400.0; // 中品質
  // それ以上は低品質
  
  // バッチング用
  final List<_DrawCall> _drawCalls = [];
  
  /// 画面境界の設定
  void setScreenBounds(Size screenSize) {
    _screenBounds = Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);
  }

  /// Paintオブジェクトの取得（プール使用）
  Paint getPaint() {
    if (_enableObjectPooling && _paintPool.isNotEmpty) {
      final paint = _paintPool.removeLast();
      // Paintオブジェクトをリセット（reset()メソッドは存在しないため手動でリセット）
      paint.color = const Color(0xFF000000);
      paint.strokeWidth = 1.0;
      paint.style = PaintingStyle.fill;
      return paint;
    }
    return Paint();
  }

  /// Paintオブジェクトの返却
  void returnPaint(Paint paint) {
    if (_enableObjectPooling && _paintPool.length < 50) {
      _paintPool.add(paint);
    }
  }

  /// Pathオブジェクトの取得（プール使用）
  Path getPath() {
    if (_enableObjectPooling && _pathPool.isNotEmpty) {
      final path = _pathPool.removeLast();
      path.reset();
      return path;
    }
    return Path();
  }

  /// Pathオブジェクトの返却
  void returnPath(Path path) {
    if (_enableObjectPooling && _pathPool.length < 30) {
      _pathPool.add(path);
    }
  }

  /// Rectオブジェクトの取得（プール使用）
  Rect getRect(double left, double top, double width, double height) {
    if (_enableObjectPooling && _rectPool.isNotEmpty) {
      // Rectは不変オブジェクトなので、新しく作成
      _rectPool.removeLast();
    }
    return Rect.fromLTWH(left, top, width, height);
  }

  /// 視錐台カリング - オブジェクトが画面内にあるかチェック
  bool isInFrustum(Rect objectBounds, {double margin = 50.0}) {
    if (!_enableFrustumCulling) return true;
    
    final expandedScreen = _screenBounds.inflate(margin);
    return expandedScreen.overlaps(objectBounds);
  }

  /// LOD（Level of Detail）の決定
  RenderQuality getLevelOfDetail(Offset objectPosition, Offset cameraPosition) {
    if (!_enableLevelOfDetail) return RenderQuality.high;
    
    final distance = (objectPosition - cameraPosition).distance;
    
    if (distance < _lodDistance1) {
      return RenderQuality.high;
    } else if (distance < _lodDistance2) {
      return RenderQuality.medium;
    } else {
      return RenderQuality.low;
    }
  }

  /// 描画コールのバッチング開始
  void beginBatching() {
    if (_enableBatching) {
      _drawCalls.clear();
    }
  }

  /// 描画コールの追加
  void addDrawCall(_DrawCall drawCall) {
    if (_enableBatching) {
      _drawCalls.add(drawCall);
    }
  }

  /// バッチング済み描画コールの実行
  void executeBatch(Canvas canvas) {
    if (!_enableBatching || _drawCalls.isEmpty) return;
    
    // 描画タイプ別にソート（状態変更を最小化）
    _drawCalls.sort((a, b) => a.type.index.compareTo(b.type.index));
    
    for (final drawCall in _drawCalls) {
      drawCall.execute(canvas);
    }
    
    _drawCalls.clear();
  }

  /// 最適化されたCircle描画
  void drawOptimizedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint, {
    RenderQuality quality = RenderQuality.high,
  }) {
    final bounds = Rect.fromCircle(center: center, radius: radius);
    
    // カリングチェック
    if (!isInFrustum(bounds)) return;
    
    // LODに基づく品質調整
    switch (quality) {
      case RenderQuality.high:
        canvas.drawCircle(center, radius, paint);
        break;
      case RenderQuality.medium:
        // 中品質：若干簡略化
        canvas.drawCircle(center, radius * 0.95, paint);
        break;
      case RenderQuality.low:
        // 低品質：四角形で代用
        final rect = Rect.fromCircle(center: center, radius: radius * 0.8);
        canvas.drawRect(rect, paint);
        break;
    }
  }

  /// 最適化されたPath描画
  void drawOptimizedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    RenderQuality quality = RenderQuality.high,
  }) {
    final bounds = path.getBounds();
    
    // カリングチェック
    if (!isInFrustum(bounds)) return;
    
    // LODに基づく品質調整
    switch (quality) {
      case RenderQuality.high:
        canvas.drawPath(path, paint);
        break;
      case RenderQuality.medium:
        // 中品質：線幅を調整
        final originalWidth = paint.strokeWidth;
        paint.strokeWidth = originalWidth * 0.8;
        canvas.drawPath(path, paint);
        paint.strokeWidth = originalWidth;
        break;
      case RenderQuality.low:
        // 低品質：境界矩形で代用
        canvas.drawRect(bounds, paint);
        break;
    }
  }

  /// 最適化されたテキスト描画
  void drawOptimizedText(
    Canvas canvas,
    String text,
    Offset position,
    TextStyle style, {
    RenderQuality quality = RenderQuality.high,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    final bounds = Rect.fromLTWH(
      position.dx,
      position.dy,
      textPainter.width,
      textPainter.height,
    );
    
    // カリングチェック
    if (!isInFrustum(bounds)) return;
    
    // LODに基づく品質調整
    switch (quality) {
      case RenderQuality.high:
        textPainter.paint(canvas, position);
        break;
      case RenderQuality.medium:
        // 中品質：フォントサイズを若干縮小
        final reducedStyle = style.copyWith(
          fontSize: (style.fontSize ?? 14) * 0.9,
        );
        final reducedPainter = TextPainter(
          text: TextSpan(text: text, style: reducedStyle),
          textDirection: TextDirection.ltr,
        );
        reducedPainter.layout();
        reducedPainter.paint(canvas, position);
        break;
      case RenderQuality.low:
        // 低品質：テキストを省略または非表示
        if (text.length > 10) return; // 長いテキストは描画しない
        textPainter.paint(canvas, position);
        break;
    }
  }

  /// メモリ使用量の最適化
  void optimizeMemoryUsage() {
    // プールサイズの調整
    if (_paintPool.length > 30) {
      _paintPool.removeRange(30, _paintPool.length);
    }
    if (_pathPool.length > 20) {
      _pathPool.removeRange(20, _pathPool.length);
    }
    if (_rectPool.length > 20) {
      _rectPool.removeRange(20, _rectPool.length);
    }
    
    // 強制ガベージコレクション（デバッグ時のみ）
    if (kDebugMode) {
      // Dartのガベージコレクションは自動なので、明示的な呼び出しは不要
      debugPrint('RenderOptimizer: メモリ最適化実行');
    }
  }

  /// 最適化設定の更新
  void updateOptimizationSettings({
    bool? enableObjectPooling,
    bool? enableFrustumCulling,
    bool? enableLevelOfDetail,
    bool? enableBatching,
  }) {
    _enableObjectPooling = enableObjectPooling ?? _enableObjectPooling;
    _enableFrustumCulling = enableFrustumCulling ?? _enableFrustumCulling;
    _enableLevelOfDetail = enableLevelOfDetail ?? _enableLevelOfDetail;
    _enableBatching = enableBatching ?? _enableBatching;
    
    debugPrint('RenderOptimizer: 設定更新 - '
        'Pooling: $_enableObjectPooling, '
        'Culling: $_enableFrustumCulling, '
        'LOD: $_enableLevelOfDetail, '
        'Batching: $_enableBatching');
  }

  /// 統計情報の取得
  Map<String, dynamic> getStatistics() {
    return {
      'paintPoolSize': _paintPool.length,
      'pathPoolSize': _pathPool.length,
      'rectPoolSize': _rectPool.length,
      'pendingDrawCalls': _drawCalls.length,
      'optimizationSettings': {
        'objectPooling': _enableObjectPooling,
        'frustumCulling': _enableFrustumCulling,
        'levelOfDetail': _enableLevelOfDetail,
        'batching': _enableBatching,
      },
    };
  }
}

/// レンダリング品質レベル
enum RenderQuality {
  high,   // 高品質
  medium, // 中品質
  low,    // 低品質
}

/// 描画コール（バッチング用）
class _DrawCall {
  final DrawCallType type;
  final void Function(Canvas) execute;
  
  _DrawCall(this.type, this.execute);
}

/// 描画コールタイプ
enum DrawCallType {
  circle,
  rect,
  path,
  text,
  image,
}