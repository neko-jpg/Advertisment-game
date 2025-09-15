
import 'package:flutter/material.dart';

class DrawnLine {
  DrawnLine({required this.points, required this.creationTime});

  final List<Offset> points;
  final DateTime creationTime;
}

class LineProvider with ChangeNotifier {
  LineProvider();

  static const Duration lineLifetime = Duration(milliseconds: 1500);
  static const Duration drawCooldown = Duration(milliseconds: 1200);

  final List<DrawnLine> _lines = [];
  DateTime? _lastLineCreatedAt;

  List<DrawnLine> get lines => _lines;

  /// Indicates whether the player can start drawing a new line.
  bool get canStartNewLine {
    if (_lastLineCreatedAt == null) {
      return true;
    }
    final elapsed = DateTime.now().difference(_lastLineCreatedAt!);
    return elapsed >= drawCooldown;
  }

  /// Returns the cooldown completion percentage in the range [0, 1].
  double get cooldownProgress {
    if (_lastLineCreatedAt == null) {
      return 1.0;
    }
    final elapsed = DateTime.now().difference(_lastLineCreatedAt!);
    final ratio = elapsed.inMilliseconds / drawCooldown.inMilliseconds;
    return ratio.clamp(0.0, 1.0);
  }

  bool get isOnCooldown => !canStartNewLine;

  /// Starts a new line if the cooldown has completed.
  ///
  /// Returns `true` if the line creation succeeds.
  bool startNewLine(Offset point) {
    if (!canStartNewLine) {
      return false;
    }

    final now = DateTime.now();
    _lastLineCreatedAt = now;
    _lines.add(DrawnLine(points: [point], creationTime: now));
    notifyListeners();
    return true;
  }

  void addPointToLine(Offset point) {
    if (_lines.isEmpty) {
      return;
    }
    _lines.last.points.add(point);
    notifyListeners();
  }

  void updateLineLifetimes() {
    if (_lines.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final previousLength = _lines.length;
    _lines.removeWhere(
      (line) => now.difference(line.creationTime) > lineLifetime,
    );
    if (_lines.length != previousLength) {
      notifyListeners();
    }
  }

  void clearAllLines() {
    _lines.clear();
    _lastLineCreatedAt = null;
    notifyListeners();
  }
}
