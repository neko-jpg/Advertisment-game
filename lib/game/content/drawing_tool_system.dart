import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'models/content_models.dart';
import '../models/game_models.dart' as game_models;

/// Drawing effect configuration
class DrawingEffect {
  const DrawingEffect({
    required this.colors,
    this.strokeWidth = 3.0,
    this.opacity = 1.0,
    this.glowRadius = 0.0,
    this.animationSpeed = 1.0,
    this.particleCount = 0,
  });

  final List<Color> colors;
  final double strokeWidth;
  final double opacity;
  final double glowRadius;
  final double animationSpeed;
  final int particleCount;

  /// Create a paint object for this effect
  Paint createPaint() {
    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (colors.length == 1) {
      paint.color = colors.first.withOpacity(opacity);
    } else {
      // Create gradient for multi-color effects
      paint.shader = LinearGradient(
        colors: colors,
        stops: List.generate(colors.length, (i) => i / (colors.length - 1)),
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100));
    }

    return paint;
  }
}

/// Artwork created by the player
class PlayerArtwork {
  PlayerArtwork({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.drawingData,
    required this.toolUsed,
    required this.playTime,
    required this.score,
    this.isShared = false,
    this.likes = 0,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final List<DrawingStroke> drawingData;
  final DrawingTool toolUsed;
  final Duration playTime;
  final int score;
  bool isShared;
  int likes;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'drawingData': drawingData.map((s) => s.toJson()).toList(),
      'toolUsed': toolUsed.index,
      'playTime': playTime.inMilliseconds,
      'score': score,
      'isShared': isShared,
      'likes': likes,
    };
  }

  static PlayerArtwork fromJson(Map<String, dynamic> json) {
    return PlayerArtwork(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      drawingData: (json['drawingData'] as List<dynamic>)
          .map((s) => DrawingStroke.fromJson(s as Map<String, dynamic>))
          .toList(),
      toolUsed: DrawingTool.values[json['toolUsed'] as int],
      playTime: Duration(milliseconds: json['playTime'] as int),
      score: json['score'] as int,
      isShared: json['isShared'] as bool? ?? false,
      likes: json['likes'] as int? ?? 0,
    );
  }
}

/// Individual drawing stroke
class DrawingStroke {
  DrawingStroke({
    required this.points,
    required this.tool,
    required this.timestamp,
  });

  final List<Offset> points;
  final DrawingTool tool;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'tool': tool.index,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  static DrawingStroke fromJson(Map<String, dynamic> json) {
    return DrawingStroke(
      points: (json['points'] as List<dynamic>)
          .map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
          .toList(),
      tool: DrawingTool.values[json['tool'] as int],
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// System for managing drawing tools and artwork gallery
class DrawingToolSystem {
  DrawingToolSystem({
    required this.onStateChanged,
  });

  final VoidCallback onStateChanged;
  
  final List<PlayerArtwork> _artworkGallery = [];
  final List<DrawingStroke> _currentDrawing = [];
  DrawingTool _selectedTool = DrawingTool.basic;
  int _totalDrawingTime = 0; // in milliseconds
  int _totalStrokes = 0;

  /// Current artwork gallery
  List<PlayerArtwork> get artworkGallery => List.unmodifiable(_artworkGallery);

  /// Current drawing strokes
  List<DrawingStroke> get currentDrawing => List.unmodifiable(_currentDrawing);

  /// Selected drawing tool
  DrawingTool get selectedTool => _selectedTool;

  /// Total drawing time in milliseconds
  int get totalDrawingTime => _totalDrawingTime;

  /// Total strokes drawn
  int get totalStrokes => _totalStrokes;

  /// Get drawing effect for a tool
  DrawingEffect getDrawingEffect(DrawingTool tool) {
    switch (tool) {
      case DrawingTool.basic:
        return const DrawingEffect(
          colors: [Colors.black],
          strokeWidth: 3.0,
        );
      case DrawingTool.rainbow:
        return const DrawingEffect(
          colors: [
            Colors.red,
            Colors.orange,
            Colors.yellow,
            Colors.green,
            Colors.blue,
            Colors.purple,
          ],
          strokeWidth: 4.0,
          animationSpeed: 2.0,
        );
      case DrawingTool.glowing:
        return const DrawingEffect(
          colors: [Colors.yellow],
          strokeWidth: 3.0,
          glowRadius: 8.0,
          opacity: 0.9,
        );
      case DrawingTool.sparkle:
        return const DrawingEffect(
          colors: [Colors.pink, Colors.white],
          strokeWidth: 2.0,
          particleCount: 5,
          animationSpeed: 1.5,
        );
      case DrawingTool.fire:
        return const DrawingEffect(
          colors: [Colors.red, Colors.orange, Colors.yellow],
          strokeWidth: 5.0,
          glowRadius: 6.0,
          particleCount: 3,
          animationSpeed: 2.5,
        );
      case DrawingTool.ice:
        return const DrawingEffect(
          colors: [Colors.cyan, Colors.blue, Colors.white],
          strokeWidth: 3.0,
          glowRadius: 4.0,
          opacity: 0.8,
        );
    }
  }

  /// Select a drawing tool
  void selectTool(DrawingTool tool) {
    _selectedTool = tool;
    onStateChanged();
  }

  /// Start a new stroke
  void startStroke(Offset point) {
    final stroke = DrawingStroke(
      points: [point],
      tool: _selectedTool,
      timestamp: DateTime.now(),
    );
    _currentDrawing.add(stroke);
    _totalStrokes++;
    onStateChanged();
  }

  /// Add point to current stroke
  void addPointToStroke(Offset point) {
    if (_currentDrawing.isNotEmpty) {
      _currentDrawing.last.points.add(point);
      onStateChanged();
    }
  }

  /// End current stroke
  void endStroke() {
    // Stroke is already added to _currentDrawing in startStroke
    onStateChanged();
  }

  /// Clear current drawing
  void clearDrawing() {
    _currentDrawing.clear();
    onStateChanged();
  }

  /// Save current drawing as artwork
  PlayerArtwork saveArtwork({
    required String title,
    required Duration playTime,
    required int score,
  }) {
    final artwork = PlayerArtwork(
      id: 'artwork_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      createdAt: DateTime.now(),
      drawingData: List.from(_currentDrawing),
      toolUsed: _selectedTool,
      playTime: playTime,
      score: score,
    );

    _artworkGallery.add(artwork);
    _totalDrawingTime += playTime.inMilliseconds;
    
    // Clear current drawing after saving
    clearDrawing();
    
    onStateChanged();
    return artwork;
  }

  /// Share artwork
  void shareArtwork(String artworkId) {
    final artwork = _artworkGallery.firstWhere(
      (a) => a.id == artworkId,
      orElse: () => throw ArgumentError('Artwork not found: $artworkId'),
    );
    
    artwork.isShared = true;
    onStateChanged();
  }

  /// Like artwork
  void likeArtwork(String artworkId) {
    final artwork = _artworkGallery.firstWhere(
      (a) => a.id == artworkId,
      orElse: () => throw ArgumentError('Artwork not found: $artworkId'),
    );
    
    artwork.likes++;
    onStateChanged();
  }

  /// Delete artwork
  void deleteArtwork(String artworkId) {
    _artworkGallery.removeWhere((a) => a.id == artworkId);
    onStateChanged();
  }

  /// Get artwork statistics
  Map<String, dynamic> getArtworkStats() {
    final totalArtworks = _artworkGallery.length;
    final sharedArtworks = _artworkGallery.where((a) => a.isShared).length;
    final totalLikes = _artworkGallery.fold<int>(0, (sum, a) => sum + a.likes);
    final averageScore = totalArtworks > 0 
        ? _artworkGallery.fold<int>(0, (sum, a) => sum + a.score) / totalArtworks
        : 0.0;

    final toolUsage = <DrawingTool, int>{};
    for (final artwork in _artworkGallery) {
      toolUsage[artwork.toolUsed] = (toolUsage[artwork.toolUsed] ?? 0) + 1;
    }

    return {
      'totalArtworks': totalArtworks,
      'sharedArtworks': sharedArtworks,
      'totalLikes': totalLikes,
      'averageScore': averageScore,
      'totalDrawingTime': _totalDrawingTime,
      'totalStrokes': _totalStrokes,
      'toolUsage': toolUsage.map((k, v) => MapEntry(k.name, v)),
    };
  }

  /// Get featured artworks (highest scoring)
  List<PlayerArtwork> getFeaturedArtworks({int limit = 5}) {
    final sortedArtworks = List<PlayerArtwork>.from(_artworkGallery)
      ..sort((a, b) => b.score.compareTo(a.score));
    
    return sortedArtworks.take(limit).toList();
  }

  /// Get recent artworks
  List<PlayerArtwork> getRecentArtworks({int limit = 10}) {
    final sortedArtworks = List<PlayerArtwork>.from(_artworkGallery)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return sortedArtworks.take(limit).toList();
  }

  /// Update drawing progress from game session
  void onGameCompleted(game_models.RunStats runStats) {
    _totalDrawingTime += runStats.drawTimeMs;
    onStateChanged();
  }

  /// Generate automatic artwork title
  String generateArtworkTitle() {
    final adjectives = ['Amazing', 'Beautiful', 'Creative', 'Dynamic', 'Elegant', 'Fantastic'];
    final nouns = ['Drawing', 'Artwork', 'Creation', 'Masterpiece', 'Sketch', 'Design'];
    
    final random = math.Random();
    final adjective = adjectives[random.nextInt(adjectives.length)];
    final noun = nouns[random.nextInt(nouns.length)];
    final number = _artworkGallery.length + 1;
    
    return '$adjective $noun #$number';
  }

  /// Serialization methods

  Map<String, dynamic> toJson() {
    return {
      'artworkGallery': _artworkGallery.map((a) => a.toJson()).toList(),
      'selectedTool': _selectedTool.index,
      'totalDrawingTime': _totalDrawingTime,
      'totalStrokes': _totalStrokes,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    _artworkGallery.clear();
    _artworkGallery.addAll(
      (json['artworkGallery'] as List<dynamic>? ?? [])
          .map((a) => PlayerArtwork.fromJson(a as Map<String, dynamic>))
    );

    _selectedTool = DrawingTool.values[json['selectedTool'] as int? ?? 0];
    _totalDrawingTime = json['totalDrawingTime'] as int? ?? 0;
    _totalStrokes = json['totalStrokes'] as int? ?? 0;

    onStateChanged();
  }
}