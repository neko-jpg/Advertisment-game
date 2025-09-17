import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 形状の種類を定義
enum ShapeType {
  circle,    // 円形
  triangle,  // 三角形
  wave,      // 波形
  spiral,    // 螺旋
  unknown,   // 不明
}

/// 認識された形状の情報
class RecognizedShape {
  final ShapeType type;
  final double confidence;
  final Offset center;
  final double size;
  final List<Offset> originalPoints;
  final DateTime recognizedAt;

  const RecognizedShape({
    required this.type,
    required this.confidence,
    required this.center,
    required this.size,
    required this.originalPoints,
    required this.recognizedAt,
  });
}

/// 形状認識エンジンのメインクラス
class ShapeRecognitionEngine {
  static const double _minConfidence = 0.7;
  static const int _minPoints = 10;
  static const double _circleThreshold = 0.8;
  static const double _triangleThreshold = 0.75;
  static const double _waveThreshold = 0.7;
  static const double _spiralThreshold = 0.65;

  /// 描画された点列から形状を認識
  RecognizedShape? recognizeShape(List<Offset> points) {
    if (points.length < _minPoints) return null;

    // 点列を正規化
    final normalizedPoints = _normalizePoints(points);
    
    // 各形状の認識を試行
    final circleResult = _recognizeCircle(normalizedPoints);
    final triangleResult = _recognizeTriangle(normalizedPoints);
    final waveResult = _recognizeWave(normalizedPoints);
    final spiralResult = _recognizeSpiral(normalizedPoints);

    // 最も信頼度の高い結果を選択
    final results = [circleResult, triangleResult, waveResult, spiralResult]
        .where((result) => result != null && result.confidence >= _minConfidence)
        .toList();

    if (results.isEmpty) return null;

    results.sort((a, b) => b!.confidence.compareTo(a!.confidence));
    return results.first;
  }

  /// 点列を正規化（中心を原点に、サイズを統一）
  List<Offset> _normalizePoints(List<Offset> points) {
    if (points.isEmpty) return points;

    // 境界ボックスを計算
    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;

    for (final point in points) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }

    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;
    final scale = math.max(maxX - minX, maxY - minY);

    if (scale == 0) return points;

    // 正規化
    return points.map((point) => Offset(
      (point.dx - centerX) / scale,
      (point.dy - centerY) / scale,
    )).toList();
  }

  /// 円形認識
  RecognizedShape? _recognizeCircle(List<Offset> points) {
    if (points.length < 8) return null;

    // 中心点を計算
    final center = _calculateCenter(points);
    
    // 各点から中心までの距離を計算
    final distances = points.map((point) => 
        math.sqrt(math.pow(point.dx - center.dx, 2) + math.pow(point.dy - center.dy, 2))
    ).toList();

    final avgDistance = distances.reduce((a, b) => a + b) / distances.length;
    
    // 距離の分散を計算（円らしさの指標）
    final variance = distances.map((d) => math.pow(d - avgDistance, 2)).reduce((a, b) => a + b) / distances.length;
    final standardDeviation = math.sqrt(variance);
    
    // 円らしさを評価
    final confidence = math.max(0.0, 1.0 - (standardDeviation / avgDistance) * 2);
    
    if (confidence < _circleThreshold) return null;

    return RecognizedShape(
      type: ShapeType.circle,
      confidence: confidence,
      center: center,
      size: avgDistance * 2,
      originalPoints: points,
      recognizedAt: DateTime.now(),
    );
  }

  /// 三角形認識
  RecognizedShape? _recognizeTriangle(List<Offset> points) {
    if (points.length < 6) return null;

    // 角を検出
    final corners = _detectCorners(points, 3);
    if (corners.length != 3) return null;

    // 三角形の品質を評価
    final confidence = _evaluateTriangleQuality(corners, points);
    
    if (confidence < _triangleThreshold) return null;

    final center = _calculateCenter(corners);
    final size = _calculateTriangleSize(corners);

    return RecognizedShape(
      type: ShapeType.triangle,
      confidence: confidence,
      center: center,
      size: size,
      originalPoints: points,
      recognizedAt: DateTime.now(),
    );
  }

  /// 波形認識
  RecognizedShape? _recognizeWave(List<Offset> points) {
    if (points.length < 12) return null;

    // 波の特徴を検出
    final peaks = _detectPeaks(points);
    final valleys = _detectValleys(points);

    if (peaks.length < 2 || valleys.length < 1) return null;

    // 波の規則性を評価
    final confidence = _evaluateWaveRegularity(peaks, valleys, points);
    
    if (confidence < _waveThreshold) return null;

    final center = _calculateCenter(points);
    final size = _calculateWaveSize(points);

    return RecognizedShape(
      type: ShapeType.wave,
      confidence: confidence,
      center: center,
      size: size,
      originalPoints: points,
      recognizedAt: DateTime.now(),
    );
  }

  /// 螺旋認識
  RecognizedShape? _recognizeSpiral(List<Offset> points) {
    if (points.length < 15) return null;

    // 螺旋の特徴を検出
    final center = _calculateCenter(points);
    final confidence = _evaluateSpiralQuality(points, center);
    
    if (confidence < _spiralThreshold) return null;

    final size = _calculateSpiralSize(points, center);

    return RecognizedShape(
      type: ShapeType.spiral,
      confidence: confidence,
      center: center,
      size: size,
      originalPoints: points,
      recognizedAt: DateTime.now(),
    );
  }

  /// 中心点を計算
  Offset _calculateCenter(List<Offset> points) {
    if (points.isEmpty) return Offset.zero;
    
    double sumX = 0;
    double sumY = 0;
    
    for (final point in points) {
      sumX += point.dx;
      sumY += point.dy;
    }
    
    return Offset(sumX / points.length, sumY / points.length);
  }

  /// 角を検出
  List<Offset> _detectCorners(List<Offset> points, int expectedCorners) {
    final corners = <Offset>[];
    const angleThreshold = math.pi / 4; // 45度
    
    for (int i = 2; i < points.length - 2; i++) {
      final prev = points[i - 2];
      final curr = points[i];
      final next = points[i + 2];
      
      final angle1 = math.atan2(curr.dy - prev.dy, curr.dx - prev.dx);
      final angle2 = math.atan2(next.dy - curr.dy, next.dx - curr.dx);
      
      double angleDiff = (angle2 - angle1).abs();
      if (angleDiff > math.pi) angleDiff = 2 * math.pi - angleDiff;
      
      if (angleDiff > angleThreshold) {
        corners.add(curr);
      }
    }
    
    // 最も顕著な角を選択
    if (corners.length > expectedCorners) {
      // 簡単な実装：等間隔で選択
      final step = corners.length / expectedCorners;
      final selectedCorners = <Offset>[];
      for (int i = 0; i < expectedCorners; i++) {
        selectedCorners.add(corners[(i * step).round()]);
      }
      return selectedCorners;
    }
    
    return corners;
  }

  /// 三角形の品質を評価
  double _evaluateTriangleQuality(List<Offset> corners, List<Offset> points) {
    if (corners.length != 3) return 0.0;
    
    // 辺の長さを計算
    final side1 = _distance(corners[0], corners[1]);
    final side2 = _distance(corners[1], corners[2]);
    final side3 = _distance(corners[2], corners[0]);
    
    // 三角形の不等式をチェック
    if (side1 + side2 <= side3 || side2 + side3 <= side1 || side3 + side1 <= side2) {
      return 0.0;
    }
    
    // 点が三角形の辺に沿っているかチェック
    int pointsOnEdges = 0;
    const tolerance = 0.1;
    
    for (final point in points) {
      if (_isPointNearLine(point, corners[0], corners[1], tolerance) ||
          _isPointNearLine(point, corners[1], corners[2], tolerance) ||
          _isPointNearLine(point, corners[2], corners[0], tolerance)) {
        pointsOnEdges++;
      }
    }
    
    return pointsOnEdges / points.length;
  }

  /// 波のピークを検出
  List<Offset> _detectPeaks(List<Offset> points) {
    final peaks = <Offset>[];
    
    for (int i = 1; i < points.length - 1; i++) {
      if (points[i].dy < points[i - 1].dy && points[i].dy < points[i + 1].dy) {
        peaks.add(points[i]);
      }
    }
    
    return peaks;
  }

  /// 波の谷を検出
  List<Offset> _detectValleys(List<Offset> points) {
    final valleys = <Offset>[];
    
    for (int i = 1; i < points.length - 1; i++) {
      if (points[i].dy > points[i - 1].dy && points[i].dy > points[i + 1].dy) {
        valleys.add(points[i]);
      }
    }
    
    return valleys;
  }

  /// 波の規則性を評価
  double _evaluateWaveRegularity(List<Offset> peaks, List<Offset> valleys, List<Offset> points) {
    if (peaks.length < 2) return 0.0;
    
    // ピーク間の距離の一貫性をチェック
    final peakDistances = <double>[];
    for (int i = 1; i < peaks.length; i++) {
      peakDistances.add(_distance(peaks[i - 1], peaks[i]));
    }
    
    if (peakDistances.isEmpty) return 0.0;
    
    final avgDistance = peakDistances.reduce((a, b) => a + b) / peakDistances.length;
    final variance = peakDistances.map((d) => math.pow(d - avgDistance, 2)).reduce((a, b) => a + b) / peakDistances.length;
    
    return math.max(0.0, 1.0 - math.sqrt(variance) / avgDistance);
  }

  /// 螺旋の品質を評価
  double _evaluateSpiralQuality(List<Offset> points, Offset center) {
    // 角度と距離の変化を追跡
    double totalAngleChange = 0;
    double prevAngle = 0;
    bool firstPoint = true;
    
    for (final point in points) {
      final angle = math.atan2(point.dy - center.dy, point.dx - center.dx);
      
      if (!firstPoint) {
        double angleDiff = angle - prevAngle;
        if (angleDiff > math.pi) angleDiff -= 2 * math.pi;
        if (angleDiff < -math.pi) angleDiff += 2 * math.pi;
        totalAngleChange += angleDiff.abs();
      }
      
      prevAngle = angle;
      firstPoint = false;
    }
    
    // 螺旋は少なくとも1回転以上必要
    if (totalAngleChange < 2 * math.pi) return 0.0;
    
    // 距離の変化を評価
    final distances = points.map((point) => _distance(point, center)).toList();
    bool isIncreasing = true;
    bool isDecreasing = true;
    
    for (int i = 1; i < distances.length; i++) {
      if (distances[i] <= distances[i - 1]) isIncreasing = false;
      if (distances[i] >= distances[i - 1]) isDecreasing = false;
    }
    
    // 螺旋は距離が単調に変化する必要がある
    if (!isIncreasing && !isDecreasing) return 0.0;
    
    return math.min(1.0, totalAngleChange / (4 * math.pi));
  }

  /// 三角形のサイズを計算
  double _calculateTriangleSize(List<Offset> corners) {
    if (corners.length != 3) return 0.0;
    
    final side1 = _distance(corners[0], corners[1]);
    final side2 = _distance(corners[1], corners[2]);
    final side3 = _distance(corners[2], corners[0]);
    
    return (side1 + side2 + side3) / 3;
  }

  /// 波のサイズを計算
  double _calculateWaveSize(List<Offset> points) {
    if (points.isEmpty) return 0.0;
    
    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;
    
    for (final point in points) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }
    
    return math.sqrt(math.pow(maxX - minX, 2) + math.pow(maxY - minY, 2));
  }

  /// 螺旋のサイズを計算
  double _calculateSpiralSize(List<Offset> points, Offset center) {
    if (points.isEmpty) return 0.0;
    
    double maxDistance = 0;
    for (final point in points) {
      final distance = _distance(point, center);
      maxDistance = math.max(maxDistance, distance);
    }
    
    return maxDistance * 2;
  }

  /// 2点間の距離を計算
  double _distance(Offset p1, Offset p2) {
    return math.sqrt(math.pow(p2.dx - p1.dx, 2) + math.pow(p2.dy - p1.dy, 2));
  }

  /// 点が線分の近くにあるかチェック
  bool _isPointNearLine(Offset point, Offset lineStart, Offset lineEnd, double tolerance) {
    final lineLength = _distance(lineStart, lineEnd);
    if (lineLength == 0) return _distance(point, lineStart) <= tolerance;
    
    final t = math.max(0, math.min(1, 
        ((point.dx - lineStart.dx) * (lineEnd.dx - lineStart.dx) + 
         (point.dy - lineStart.dy) * (lineEnd.dy - lineStart.dy)) / (lineLength * lineLength)));
    
    final projection = Offset(
        lineStart.dx + t * (lineEnd.dx - lineStart.dx),
        lineStart.dy + t * (lineEnd.dy - lineStart.dy));
    
    return _distance(point, projection) <= tolerance;
  }
}