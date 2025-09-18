import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/game/content/models/content_models.dart';
import 'package:myapp/game/content/pcg/chunk_models.dart';
import 'package:myapp/game/content/pcg/chunk_spawner.dart';

void main() {
  ChunkPrefab createPrefab({
    required String id,
    String entryProfile = ChunkProfiles.ground,
    double entryHeight = 0,
    String exitProfile = ChunkProfiles.ground,
    double exitHeight = 0,
    Set<VisualTheme>? themes,
    double length = 120,
    double minDifficulty = 0,
    double maxDifficulty = 1,
    bool isStarter = false,
    bool isTransition = false,
    bool isFallback = false,
  }) {
    return ChunkPrefab(
      id: id,
      themes: themes ?? const {VisualTheme.classic},
      length: length,
      entry: ChunkEndpoint(profile: entryProfile, height: entryHeight),
      exit: ChunkEndpoint(profile: exitProfile, height: exitHeight),
      difficulty: DifficultyBracket(min: minDifficulty, max: maxDifficulty),
      isStarter: isStarter,
      isTransition: isTransition,
      isFallback: isFallback,
    );
  }

  test('initializes queue with compatible chunks', () {
    final starter = createPrefab(
      id: 'start',
      entryProfile: ChunkProfiles.start,
      exitProfile: ChunkProfiles.ground,
      isStarter: true,
      isFallback: true,
    );
    final ground = createPrefab(id: 'ground');
    final spawner = ChunkSpawner(
      prefabs: [starter, ground],
      queueLength: 3,
      random: math.Random(1),
    )..updateDifficulty(0.25);

    spawner.initialize(startingChunk: starter);

    expect(spawner.activeChunks.length, 3);
    expect(spawner.activeChunks.first.prefab.id, 'start');
    expect(spawner.activeChunks[1].prefab.id, equals('ground'));
  });

  test('respects connector compatibility and uses transition chunks', () {
    final starter = createPrefab(
      id: 'start',
      entryProfile: ChunkProfiles.start,
      exitProfile: ChunkProfiles.ground,
      isStarter: true,
      isFallback: true,
    );
    final transition = createPrefab(
      id: 'transition',
      entryProfile: ChunkProfiles.ground,
      exitProfile: ChunkProfiles.high,
      isTransition: true,
    );
    final elevated = createPrefab(
      id: 'elevated',
      entryProfile: ChunkProfiles.high,
      exitProfile: ChunkProfiles.high,
    );

    final spawner = ChunkSpawner(
      prefabs: [starter, transition, elevated],
      queueLength: 3,
      random: math.Random(2),
    )..updateDifficulty(0.6);

    spawner.initialize(startingChunk: starter);

    expect(spawner.activeChunks[1].prefab.id, 'transition');
    expect(spawner.activeChunks[2].prefab.id, 'elevated');
  });

  test('advancing removes consumed chunks and keeps queue filled', () {
    final starter = createPrefab(
      id: 'start',
      entryProfile: ChunkProfiles.start,
      exitProfile: ChunkProfiles.ground,
      isStarter: true,
      isFallback: true,
      length: 100,
    );
    final ground = createPrefab(id: 'ground', length: 140);

    final spawner = ChunkSpawner(
      prefabs: [starter, ground],
      queueLength: 3,
      despawnBuffer: 50,
      random: math.Random(3),
    )..updateDifficulty(0.1);

    spawner.initialize(startingChunk: starter);
    spawner.advance(220); // Should remove the starter chunk.

    expect(spawner.activeChunks.length, 3);
    expect(spawner.activeChunks.first.prefab.id, isNot('start'));
  });

  test('difficulty filtering selects appropriate prefab', () {
    final starter = createPrefab(
      id: 'start',
      entryProfile: ChunkProfiles.start,
      exitProfile: ChunkProfiles.ground,
      isStarter: true,
      isFallback: true,
    );
    final easy = createPrefab(
      id: 'easy',
      minDifficulty: 0,
      maxDifficulty: 0.5,
    );
    final hard = createPrefab(
      id: 'hard',
      minDifficulty: 0.6,
      maxDifficulty: 1.0,
    );

    final spawner = ChunkSpawner(
      prefabs: [starter, easy, hard],
      queueLength: 2,
      random: math.Random(4),
    )..updateDifficulty(0.8);

    spawner.initialize(startingChunk: starter);

    expect(spawner.activeChunks[1].prefab.id, 'hard');
  });
}
