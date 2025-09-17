import 'package:flutter/material.dart';

/// 線管理プロバイダー
class LineProvider with ChangeNotifier {
  final List<DrawnLine> _lines = [];
  
  List<DrawnLine> get lines => List.unmodifiable(_lines);
  
  /// 線の追加
  void addLine(DrawnLine line) {
    _lines.add(line);
    notifyListeners();
  }
  
  /// 線の更新
  void update(double deltaTime) {
    // 線の更新ロジック
    notifyListeners();
  }
  
  /// 古い線のクリア
  void clearOldLines() {
    final now = DateTime.now();
    _lines.removeWhere((line) => 
      now.difference(line.createdAt).inSeconds > 30
    );
    notifyListeners();
  }
  
  /// リセット
  void reset() {
    _lines.clear();
    notifyListeners();
  }
}

/// 描画された線クラス
class DrawnLine {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final DateTime createdAt;
  
  DrawnLine({
    required this.points,
    this.color = Colors.white,
    this.strokeWidth = 2.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}