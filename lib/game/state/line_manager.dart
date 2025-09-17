import 'dart:math' as math;

import 'package:flutter/material.dart';

const Duration _kLineLifetime = Duration(milliseconds: 3200);
const _kInkRechargeDurationMs = 2600.0;
const _kMinimumPointDistance = 4.0;

/// Manages the player's drawn platforms and ink resource.
class LineProvider with ChangeNotifier {
  LineProvider();

  static const Duration lineLifetime = _kLineLifetime;

  final List<DrawnLine> _lines = <DrawnLine>[];
  DrawnLine? _activeLine;

  double _inkCharge = 1.0;
  double _regenMultiplier = 1.0;
  DateTime _lastUpdate = DateTime.now();
  int _signature = 0;

  /// Currently active lines in the world.
  List<DrawnLine> get lines => List.unmodifiable(_lines);

  /// Whether the player is actively drawing a line.
  bool get isDrawing => _activeLine != null;

  /// Signature that changes whenever line geometry mutates.
  int get signature => _signature;

  /// Amount of ink available (0-1 range).
  double get inkProgress => _inkCharge.clamp(0.0, 1.0);

  /// Whether a new line can be started.
  bool get canStartNewLine => !isDrawing && inkProgress >= 0.999;

  /// Applies upgrade modifiers coming from meta progression.
  void configureUpgrades({required double regenMultiplier}) {
    _regenMultiplier = regenMultiplier.clamp(0.25, 4.0);
  }

  /// Attempts to start a new line at the provided position.
  bool startNewLine(Offset start) {
    if (!canStartNewLine) {
      return false;
    }
    _activeLine = DrawnLine(points: <Offset>[start]);
    _lines.add(_activeLine!);
    _inkCharge = 0.0;
    _lastUpdate = DateTime.now();
    _bumpSignature();
    notifyListeners();
    return true;
  }

  /// Adds a point to the currently drawn line.
  void addPointToLine(Offset point) {
    final DrawnLine? line = _activeLine;
    if (line == null) {
      return;
    }
    final Offset? last = line.lastPoint;
    if (last != null) {
      if ((last - point).distance < _kMinimumPointDistance) {
        return;
      }
    }
    line.addPoint(point);
    _bumpSignature();
    notifyListeners();
  }

  /// Finalises the currently active line.
  void endCurrentLine() {
    final DrawnLine? line = _activeLine;
    if (line == null) {
      return;
    }
    if (line.points.length < 2) {
      _lines.remove(line);
    }
    _activeLine = null;
    _lastUpdate = DateTime.now();
    _bumpSignature();
    notifyListeners();
  }

  /// Clears all drawn geometry.
  void clearAllLines() {
    if (_lines.isEmpty && _activeLine == null) {
      return;
    }
    _lines.clear();
    _activeLine = null;
    _bumpSignature();
    notifyListeners();
  }

  /// Removes lines that are far off-screen to reclaim memory.
  void clearOldLines() {
    final DateTime now = DateTime.now();
    final int before = _lines.length;
    _lines.removeWhere(
      (DrawnLine line) =>
          now.difference(line.createdAt).inMilliseconds >
          _kLineLifetime.inMilliseconds * 2,
    );
    if (before != _lines.length) {
      _bumpSignature();
      notifyListeners();
    }
  }

  /// Updates ink recharge and line lifetimes.
  void updateLineLifetimes() {
    final DateTime now = DateTime.now();
    final double deltaMs =
        now.difference(_lastUpdate).inMilliseconds.toDouble();
    _lastUpdate = now;

    bool changed = false;

    if (!isDrawing && _inkCharge < 1.0) {
      final double regenDuration =
          _kInkRechargeDurationMs / math.max(_regenMultiplier, 0.001);
      final double deltaCharge = deltaMs / regenDuration;
      final double newCharge = math.min(1.0, _inkCharge + deltaCharge);
      if ((newCharge - _inkCharge).abs() >= 0.0001) {
        _inkCharge = newCharge;
        changed = true;
      }
    }

    final int before = _lines.length;
    _lines.removeWhere(
      (DrawnLine line) =>
          now.difference(line.createdAt).inMilliseconds >
          _kLineLifetime.inMilliseconds,
    );
    if (before != _lines.length) {
      changed = true;
      _bumpSignature();
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Ensures the ink meter is filled to the given floor (0-100 percent).
  bool grantEmergencyInk(double minimumPercent) {
    final double floor = (minimumPercent / 100).clamp(0.0, 1.0);
    if (_inkCharge >= floor) {
      return false;
    }
    _inkCharge = floor;
    notifyListeners();
    return true;
  }

  void _bumpSignature() {
    _signature = (_signature + 1) & 0x7fffffff;
  }
}

/// Represents a single line drawn by the player.
class DrawnLine {
  DrawnLine({
    required List<Offset> points,
    this.strokeWidth = 8.0,
    DateTime? createdAt,
  })  : _points = List<Offset>.from(points),
        createdAt = createdAt ?? DateTime.now() {
    for (final Offset point in _points) {
      _expandBounds(point);
    }
  }

  final List<Offset> _points;
  final double strokeWidth;
  final DateTime createdAt;

  double _minX = double.infinity;
  double _maxX = double.negativeInfinity;

  List<Offset> get points => List.unmodifiable(_points);
  double get minX => _minX;
  double get maxX => _maxX;
  Offset? get lastPoint => _points.isEmpty ? null : _points.last;

  void addPoint(Offset point) {
    _points.add(point);
    _expandBounds(point);
  }

  void _expandBounds(Offset point) {
    _minX = math.min(_minX, point.dx);
    _maxX = math.max(_maxX, point.dx);
  }
}
