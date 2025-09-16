
import 'package:flutter/material.dart';

class DrawnLine {
  DrawnLine({required this.points, required this.creationTime});

  final List<Offset> points;
  final DateTime creationTime;
}

class LineProvider with ChangeNotifier {
  LineProvider();

  static const Duration lineLifetime = Duration(milliseconds: 2100);
  static const double _baseMaxInk = 100.0;
  static const double _minInkToStart = 8.0;
  static const double _baseInkRegenPerSecond = 28.0;
  static const double _inkCostPerPixel = 0.45;
  static const double _pointDistanceThreshold = 4.0;

  final List<DrawnLine> _lines = [];
  double _inkAmount = _baseMaxInk;
  bool _isDrawing = false;
  DateTime? _lastInkUpdate;
  double _regenMultiplier = 1.0;
  double _capacityBonus = 0.0;

  List<DrawnLine> get lines => _lines;

  double get inkAmount => _inkAmount;

  double get _maxInk => (_baseMaxInk + _capacityBonus).clamp(60.0, 200.0);

  double get inkProgress => (_inkAmount / _maxInk).clamp(0.0, 1.0);

  bool get canStartNewLine => _inkAmount >= _minInkToStart;

  bool get isDrawing => _isDrawing;

  bool startNewLine(Offset point) {
    _refreshInk();
    if (!canStartNewLine) {
      return false;
    }

    final now = DateTime.now();
    _lastInkUpdate = now;
    _isDrawing = true;
    _lines.add(DrawnLine(points: [point], creationTime: now));
    notifyListeners();
    return true;
  }

  void addPointToLine(Offset point) {
    if (_lines.isEmpty || !_isDrawing) {
      return;
    }

    _refreshInk();
    final currentLine = _lines.last;
    final previousPoint = currentLine.points.last;
    final distance = (point - previousPoint).distance;
    if (distance < _pointDistanceThreshold) {
      return;
    }

    if (_inkAmount <= 0) {
      _isDrawing = false;
      notifyListeners();
      return;
    }

    final inkCost = distance * _inkCostPerPixel;
    if (inkCost > _inkAmount) {
      final ratio = _inkAmount / inkCost;
      final cappedPoint = Offset.lerp(previousPoint, point, ratio);
      if (cappedPoint != null) {
        currentLine.points.add(cappedPoint);
      }
      _inkAmount = 0;
      _isDrawing = false;
      notifyListeners();
      return;
    }

    _inkAmount = (_inkAmount - inkCost).clamp(0.0, _maxInk);
    currentLine.points.add(point);
    notifyListeners();
  }

  void endCurrentLine() {
    if (!_isDrawing) {
      return;
    }
    _isDrawing = false;
    notifyListeners();
  }

  void updateLineLifetimes() {
    final now = DateTime.now();
    final previousInk = _inkAmount;
    final previousLength = _lines.length;

    if (_lastInkUpdate == null) {
      _lastInkUpdate = now;
    }

    final elapsed = now.difference(_lastInkUpdate!);
    if (elapsed.inMilliseconds > 0) {
      _lastInkUpdate = now;
      if (_inkAmount < _maxInk) {
        final regenAmount = _currentRegenPerSecond *
            elapsed.inMilliseconds /
            1000.0;
        _inkAmount = (_inkAmount + regenAmount).clamp(0.0, _maxInk);
      }
    }

    _lines.removeWhere(
      (line) => now.difference(line.creationTime) > lineLifetime,
    );

    if (_lines.length != previousLength || _inkAmount != previousInk) {
      notifyListeners();
    }
  }

  void clearAllLines() {
    _lines.clear();
    _inkAmount = _maxInk;
    _isDrawing = false;
    _lastInkUpdate = null;
    notifyListeners();
  }

  void configureUpgrades({
    double? regenMultiplier,
    double? capacityBonus,
  }) {
    if (regenMultiplier != null) {
      _regenMultiplier = regenMultiplier.clamp(0.5, 3.0);
    }
    if (capacityBonus != null) {
      _capacityBonus = capacityBonus.clamp(0, 120.0);
      _inkAmount = _inkAmount.clamp(0.0, _maxInk);
    }
    notifyListeners();
  }

  double get _currentRegenPerSecond =>
      _baseInkRegenPerSecond * _regenMultiplier;

  void _refreshInk() {
    final now = DateTime.now();
    if (_lastInkUpdate == null) {
      _lastInkUpdate = now;
      return;
    }
    final elapsed = now.difference(_lastInkUpdate!);
    if (elapsed.inMilliseconds <= 0) {
      return;
    }
    _lastInkUpdate = now;
    if (_inkAmount >= _maxInk) {
      return;
    }
    final regenAmount =
        _currentRegenPerSecond * elapsed.inMilliseconds / 1000.0;
    _inkAmount = (_inkAmount + regenAmount).clamp(0.0, _maxInk);
  }
}
