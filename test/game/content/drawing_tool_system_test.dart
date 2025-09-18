import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/game/content/drawing_tool_system.dart';
import 'package:myapp/game/content/models/content_models.dart';
import 'package:myapp/game/models/game_models.dart' as game_models;

void main() {
  group('DrawingToolSystem', () {
    late DrawingToolSystem system;
    bool stateChanged = false;

    setUp(() {
      stateChanged = false;
      system = DrawingToolSystem(
        onStateChanged: () => stateChanged = true,
      );
    });

    test('initializes with default values', () {
      expect(system.selectedTool, equals(DrawingTool.basic));
      expect(system.artworkGallery, isEmpty);
      expect(system.currentDrawing, isEmpty);
      expect(system.totalDrawingTime, equals(0));
      expect(system.totalStrokes, equals(0));
    });

    test('can select different drawing tools', () {
      system.selectTool(DrawingTool.rainbow);
      expect(system.selectedTool, equals(DrawingTool.rainbow));
      expect(stateChanged, isTrue);
    });

    test('provides correct drawing effects for each tool', () {
      // Test basic tool
      final basicEffect = system.getDrawingEffect(DrawingTool.basic);
      expect(basicEffect.colors, equals([Colors.black]));
      expect(basicEffect.strokeWidth, equals(3.0));

      // Test rainbow tool
      final rainbowEffect = system.getDrawingEffect(DrawingTool.rainbow);
      expect(rainbowEffect.colors.length, equals(6));
      expect(rainbowEffect.animationSpeed, equals(2.0));

      // Test glowing tool
      final glowingEffect = system.getDrawingEffect(DrawingTool.glowing);
      expect(glowingEffect.colors, equals([Colors.yellow]));
      expect(glowingEffect.glowRadius, equals(8.0));

      // Test sparkle tool
      final sparkleEffect = system.getDrawingEffect(DrawingTool.sparkle);
      expect(sparkleEffect.particleCount, equals(5));

      // Test fire tool
      final fireEffect = system.getDrawingEffect(DrawingTool.fire);
      expect(fireEffect.colors.length, equals(3));
      expect(fireEffect.glowRadius, equals(6.0));

      // Test ice tool
      final iceEffect = system.getDrawingEffect(DrawingTool.ice);
      expect(iceEffect.opacity, equals(0.8));
    });

    test('can create drawing effects paint objects', () {
      final effect = system.getDrawingEffect(DrawingTool.basic);
      final paint = effect.createPaint();
      
      expect(paint.strokeWidth, equals(3.0));
      expect(paint.style, equals(PaintingStyle.stroke));
      expect(paint.strokeCap, equals(StrokeCap.round));
      expect(paint.strokeJoin, equals(StrokeJoin.round));
    });

    test('can start and manage drawing strokes', () {
      system.startStroke(const Offset(10, 10));
      
      expect(system.currentDrawing.length, equals(1));
      expect(system.totalStrokes, equals(1));
      expect(stateChanged, isTrue);
      
      final stroke = system.currentDrawing.first;
      expect(stroke.points.length, equals(1));
      expect(stroke.points.first, equals(const Offset(10, 10)));
      expect(stroke.tool, equals(DrawingTool.basic));
    });

    test('can add points to current stroke', () {
      system.startStroke(const Offset(10, 10));
      system.addPointToStroke(const Offset(20, 20));
      system.addPointToStroke(const Offset(30, 30));
      
      final stroke = system.currentDrawing.first;
      expect(stroke.points.length, equals(3));
      expect(stroke.points[1], equals(const Offset(20, 20)));
      expect(stroke.points[2], equals(const Offset(30, 30)));
    });

    test('can clear current drawing', () {
      system.startStroke(const Offset(10, 10));
      system.addPointToStroke(const Offset(20, 20));
      
      expect(system.currentDrawing.length, equals(1));
      
      system.clearDrawing();
      
      expect(system.currentDrawing, isEmpty);
      expect(stateChanged, isTrue);
    });

    test('can save artwork', () {
      system.selectTool(DrawingTool.rainbow);
      system.startStroke(const Offset(10, 10));
      system.addPointToStroke(const Offset(20, 20));
      
      final artwork = system.saveArtwork(
        title: 'Test Artwork',
        playTime: const Duration(minutes: 2),
        score: 150,
      );
      
      expect(artwork.title, equals('Test Artwork'));
      expect(artwork.toolUsed, equals(DrawingTool.rainbow));
      expect(artwork.playTime, equals(const Duration(minutes: 2)));
      expect(artwork.score, equals(150));
      expect(artwork.drawingData.length, equals(1));
      expect(artwork.drawingData.first.points.length, equals(2));
      
      expect(system.artworkGallery.length, equals(1));
      expect(system.currentDrawing, isEmpty); // Should be cleared after saving
      expect(system.totalDrawingTime, equals(120000)); // 2 minutes in milliseconds
    });

    test('can share artwork', () {
      system.startStroke(const Offset(10, 10));
      final artwork = system.saveArtwork(
        title: 'Test Artwork',
        playTime: const Duration(seconds: 30),
        score: 100,
      );
      
      expect(artwork.isShared, isFalse);
      
      system.shareArtwork(artwork.id);
      
      expect(artwork.isShared, isTrue);
      expect(stateChanged, isTrue);
    });

    test('can like artwork', () {
      system.startStroke(const Offset(10, 10));
      final artwork = system.saveArtwork(
        title: 'Test Artwork',
        playTime: const Duration(seconds: 30),
        score: 100,
      );
      
      expect(artwork.likes, equals(0));
      
      system.likeArtwork(artwork.id);
      
      expect(artwork.likes, equals(1));
      expect(stateChanged, isTrue);
      
      system.likeArtwork(artwork.id);
      expect(artwork.likes, equals(2));
    });

    test('can delete artwork', () {
      system.startStroke(const Offset(10, 10));
      final artwork = system.saveArtwork(
        title: 'Test Artwork',
        playTime: const Duration(seconds: 30),
        score: 100,
      );
      
      expect(system.artworkGallery.length, equals(1));
      
      system.deleteArtwork(artwork.id);
      
      expect(system.artworkGallery, isEmpty);
      expect(stateChanged, isTrue);
    });

    test('provides artwork statistics', () {
      // Create multiple artworks
      system.selectTool(DrawingTool.basic);
      system.startStroke(const Offset(10, 10));
      final artwork1 = system.saveArtwork(
        title: 'Artwork 1',
        playTime: const Duration(minutes: 1),
        score: 100,
      );
      
      system.selectTool(DrawingTool.rainbow);
      system.startStroke(const Offset(20, 20));
      final artwork2 = system.saveArtwork(
        title: 'Artwork 2',
        playTime: const Duration(minutes: 2),
        score: 200,
      );
      
      system.shareArtwork(artwork1.id);
      system.likeArtwork(artwork1.id);
      system.likeArtwork(artwork2.id);
      system.likeArtwork(artwork2.id);
      
      final stats = system.getArtworkStats();
      
      expect(stats['totalArtworks'], equals(2));
      expect(stats['sharedArtworks'], equals(1));
      expect(stats['totalLikes'], equals(3));
      expect(stats['averageScore'], equals(150.0));
      expect(stats['totalDrawingTime'], equals(180000)); // 3 minutes
      expect(stats['totalStrokes'], equals(2));
      
      final toolUsage = stats['toolUsage'] as Map<String, int>;
      expect(toolUsage['basic'], equals(1));
      expect(toolUsage['rainbow'], equals(1));
    });

    test('provides featured artworks (highest scoring)', () {
      // Create artworks with different scores
      for (int i = 0; i < 5; i++) {
        system.startStroke(Offset(i * 10.0, i * 10.0));
        system.saveArtwork(
          title: 'Artwork $i',
          playTime: const Duration(seconds: 30),
          score: i * 100, // Scores: 0, 100, 200, 300, 400
        );
      }
      
      final featured = system.getFeaturedArtworks(limit: 3);
      
      expect(featured.length, equals(3));
      expect(featured[0].score, equals(400)); // Highest score first
      expect(featured[1].score, equals(300));
      expect(featured[2].score, equals(200));
    });

    test('provides recent artworks (most recent first)', () {
      // Create artworks
      final artworks = <PlayerArtwork>[];
      for (int i = 0; i < 3; i++) {
        system.startStroke(Offset(i * 10.0, i * 10.0));
        final artwork = system.saveArtwork(
          title: 'Artwork $i',
          playTime: const Duration(seconds: 30),
          score: 100,
        );
        artworks.add(artwork);
      }
      
      final recent = system.getRecentArtworks(limit: 2);
      
      expect(recent.length, equals(2));
      // The most recent should be the last one created
      expect(recent[0].id, equals(artworks[2].id)); // Most recent first
      expect(recent[1].id, equals(artworks[1].id));
    });

    test('updates drawing time from game sessions', () {
      expect(system.totalDrawingTime, equals(0));
      
      system.onGameCompleted(const game_models.RunStats(
        duration: Duration(seconds: 30),
        score: 100,
        coins: 50,
        usedLine: true,
        jumpsPerformed: 5,
        drawTimeMs: 5000, // 5 seconds
        accidentDeath: false,
        nearMisses: 0,
        inkEfficiency: 1.0,
      ));
      
      expect(system.totalDrawingTime, equals(5000));
      expect(stateChanged, isTrue);
    });

    test('generates automatic artwork titles', () {
      final title1 = system.generateArtworkTitle();
      expect(title1, contains('#1'));
      
      // Save an artwork to increment the counter
      system.startStroke(const Offset(10, 10));
      system.saveArtwork(
        title: 'Test',
        playTime: const Duration(seconds: 30),
        score: 100,
      );
      
      final title2 = system.generateArtworkTitle();
      expect(title2, contains('#2'));
    });

    test('serialization works correctly', () {
      // Set up some state
      system.selectTool(DrawingTool.glowing);
      system.startStroke(const Offset(10, 10));
      system.addPointToStroke(const Offset(20, 20));
      
      final artwork = system.saveArtwork(
        title: 'Test Artwork',
        playTime: const Duration(minutes: 1),
        score: 150,
      );
      
      system.shareArtwork(artwork.id);
      system.likeArtwork(artwork.id);
      
      // Serialize
      final json = system.toJson();
      
      // Create new system and deserialize
      final newSystem = DrawingToolSystem(onStateChanged: () {});
      newSystem.fromJson(json);
      
      // Verify state is preserved
      expect(newSystem.selectedTool, equals(DrawingTool.glowing));
      expect(newSystem.artworkGallery.length, equals(1));
      expect(newSystem.totalDrawingTime, equals(60000));
      expect(newSystem.totalStrokes, equals(1));
      
      final restoredArtwork = newSystem.artworkGallery.first;
      expect(restoredArtwork.title, equals('Test Artwork'));
      expect(restoredArtwork.toolUsed, equals(DrawingTool.glowing));
      expect(restoredArtwork.score, equals(150));
      expect(restoredArtwork.isShared, isTrue);
      expect(restoredArtwork.likes, equals(1));
      expect(restoredArtwork.drawingData.length, equals(1));
      expect(restoredArtwork.drawingData.first.points.length, equals(2));
    });

    test('handles edge cases gracefully', () {
      // Try to add point without starting stroke
      system.addPointToStroke(const Offset(10, 10));
      expect(system.currentDrawing, isEmpty);
      
      // Try to share non-existent artwork
      expect(() => system.shareArtwork('non_existent'), throwsArgumentError);
      
      // Try to like non-existent artwork
      expect(() => system.likeArtwork('non_existent'), throwsArgumentError);
      
      // Try to delete non-existent artwork
      system.deleteArtwork('non_existent'); // Should not throw
      
      // Get featured artworks when none exist
      final featured = system.getFeaturedArtworks();
      expect(featured, isEmpty);
      
      // Get recent artworks when none exist
      final recent = system.getRecentArtworks();
      expect(recent, isEmpty);
    });

    test('drawing stroke serialization works correctly', () {
      final stroke = DrawingStroke(
        points: [const Offset(10, 10), const Offset(20, 20)],
        tool: DrawingTool.rainbow,
        timestamp: DateTime.now(),
      );
      
      final json = stroke.toJson();
      final restoredStroke = DrawingStroke.fromJson(json);
      
      expect(restoredStroke.points.length, equals(2));
      expect(restoredStroke.points[0], equals(const Offset(10, 10)));
      expect(restoredStroke.points[1], equals(const Offset(20, 20)));
      expect(restoredStroke.tool, equals(DrawingTool.rainbow));
      expect(restoredStroke.timestamp.millisecondsSinceEpoch,
             equals(stroke.timestamp.millisecondsSinceEpoch));
    });

    test('player artwork serialization works correctly', () {
      final artwork = PlayerArtwork(
        id: 'test_id',
        title: 'Test Artwork',
        createdAt: DateTime.now(),
        drawingData: [
          DrawingStroke(
            points: [const Offset(10, 10)],
            tool: DrawingTool.sparkle,
            timestamp: DateTime.now(),
          ),
        ],
        toolUsed: DrawingTool.sparkle,
        playTime: const Duration(minutes: 2),
        score: 300,
        isShared: true,
        likes: 5,
      );
      
      final json = artwork.toJson();
      final restoredArtwork = PlayerArtwork.fromJson(json);
      
      expect(restoredArtwork.id, equals('test_id'));
      expect(restoredArtwork.title, equals('Test Artwork'));
      expect(restoredArtwork.toolUsed, equals(DrawingTool.sparkle));
      expect(restoredArtwork.playTime, equals(const Duration(minutes: 2)));
      expect(restoredArtwork.score, equals(300));
      expect(restoredArtwork.isShared, isTrue);
      expect(restoredArtwork.likes, equals(5));
      expect(restoredArtwork.drawingData.length, equals(1));
      expect(restoredArtwork.drawingData.first.tool, equals(DrawingTool.sparkle));
    });
  });
}
