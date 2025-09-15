
import 'package:flutter/material.dart';

class DrawnLine {
  final List<Offset> points;
  final DateTime creationTime;

  DrawnLine({required this.points, required this.creationTime});
}

class LineProvider with ChangeNotifier {
  final List<DrawnLine> _lines = [];
  static const Duration _lineLifetime = Duration(seconds: 4);

  List<DrawnLine> get lines => _lines;

  void startNewLine(Offset point) {
    _lines.add(DrawnLine(points: [point], creationTime: DateTime.now()));
    notifyListeners();
  }

  void addPointToLine(Offset point) {
    if (_lines.isNotEmpty) {
      _lines.last.points.add(point);
      notifyListeners();
    }
  }

  void updateLineLifetimes() {
    final now = DateTime.now();
    _lines.removeWhere((line) => now.difference(line.creationTime) > _lineLifetime);
    notifyListeners();
  }

  void clearAllLines() {
    _lines.clear();
    notifyListeners();
  }
}
