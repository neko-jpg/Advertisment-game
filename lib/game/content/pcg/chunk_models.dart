import 'package:flutter/foundation.dart';

import '../models/content_models.dart';

/// Canonical connector profiles used to attach chunk prefabs together.
///
/// The profiles describe the relative elevation of the entry/exit interface
/// so that different chunks can be joined without creating impossible gaps or
/// steps. `any` can connect to any other profile and is primarily used for
/// special transition pieces.
class ChunkProfiles {
  ChunkProfiles._();

  static const String any = 'any';
  static const String start = 'start';
  static const String ground = 'ground';
  static const String low = 'low';
  static const String mid = 'mid';
  static const String high = 'high';
}

/// Endpoint descriptor for the entry or exit of a chunk prefab.
class ChunkEndpoint {
  const ChunkEndpoint({
    required this.profile,
    required this.height,
  }) : assert(height.isFinite, 'Endpoint height must be finite');

  /// Canonical profile identifier. See [ChunkProfiles] for recommended values.
  final String profile;

  /// Physical height (in game units) relative to the baseline ground level.
  final double height;

  /// Returns `true` when this endpoint can connect with [other] while obeying
  /// the provided [maxHeightDelta] tolerance.
  bool isCompatibleWith(
    ChunkEndpoint other, {
    double maxHeightDelta = 40,
  }) {
    final profileMatches = profile == ChunkProfiles.any ||
        other.profile == ChunkProfiles.any ||
        profile == other.profile;
    if (!profileMatches) {
      return false;
    }
    return (height - other.height).abs() <= maxHeightDelta;
  }

  ChunkEndpoint copyWith({String? profile, double? height}) {
    return ChunkEndpoint(
      profile: profile ?? this.profile,
      height: height ?? this.height,
    );
  }
}

/// Base class for elements contained within a prefab chunk.
@immutable
abstract class ChunkElement {
  const ChunkElement();
}

/// Platform geometry spawned as part of a chunk.
class PlatformElement extends ChunkElement {
  const PlatformElement({
    required this.startX,
    required this.endX,
    required this.height,
    this.type = 'platform',
  })  : assert(startX.isFinite),
        assert(endX.isFinite),
        assert(height.isFinite),
        assert(endX >= startX, 'endX must be greater than startX');

  final double startX;
  final double endX;
  final double height;
  final String type;
}

/// Obstacle spawn marker for the chunk.
class ObstacleElement extends ChunkElement {
  const ObstacleElement({
    required this.positionX,
    required this.height,
    this.obstacleType = 'standard',
  })  : assert(positionX.isFinite),
        assert(height.isFinite);

  final double positionX;
  final double height;
  final String obstacleType;
}

/// Collectible spawn marker for the chunk.
class CollectibleElement extends ChunkElement {
  const CollectibleElement({
    required this.positionX,
    required this.height,
    this.rewardType = 'coin',
  })  : assert(positionX.isFinite),
        assert(height.isFinite);

  final double positionX;
  final double height;
  final String rewardType;
}

/// Difficulty band supported by a chunk prefab.
class DifficultyBracket {
  const DifficultyBracket({
    required this.min,
    required this.max,
  })  : assert(min <= max),
        assert(min >= 0),
        assert(max <= 1.0);

  final double min;
  final double max;

  bool contains(double value) => value >= min && value <= max;
}

/// Immutable prefab definition used by the procedural chunk spawner.
@immutable
class ChunkPrefab {
  const ChunkPrefab({
    required this.id,
    required this.themes,
    required this.length,
    required this.entry,
    required this.exit,
    this.difficulty = const DifficultyBracket(min: 0, max: 1),
    this.tags = const <String>{},
    this.elements = const <ChunkElement>[],
    this.isTransition = false,
    this.isStarter = false,
    this.isFallback = false,
  })  : assert(length > 0, 'Chunk length must be positive');

  /// Unique identifier for debugging and analytics.
  final String id;

  /// Themes that can use this chunk. Empty set means theme-agnostic.
  final Set<VisualTheme> themes;

  /// Horizontal length (in game units) covered by this chunk.
  final double length;

  /// Entry interface descriptor.
  final ChunkEndpoint entry;

  /// Exit interface descriptor.
  final ChunkEndpoint exit;

  /// Supported difficulty bracket.
  final DifficultyBracket difficulty;

  /// Arbitrary metadata tags (e.g. `airborne`, `combo`, ...).
  final Set<String> tags;

  /// Structured description of contained elements.
  final List<ChunkElement> elements;

  /// `true` if the chunk is intended to bridge height gaps.
  final bool isTransition;

  /// `true` if this chunk can be used as the first chunk for a run.
  final bool isStarter;

  /// `true` if this chunk can be used as a last-resort fallback.
  final bool isFallback;

  bool supportsTheme(VisualTheme theme) => themes.isEmpty || themes.contains(theme);

  bool supportsDifficulty(double value) => difficulty.contains(value);
}

/// Runtime instance of a chunk placed inside the world.
class ChunkInstance {
  ChunkInstance({
    required this.prefab,
    required this.startX,
  }) : assert(startX.isFinite);

  final ChunkPrefab prefab;
  final double startX;

  double get endX => startX + prefab.length;
  ChunkEndpoint get entry => prefab.entry;
  ChunkEndpoint get exit => prefab.exit;

  double get entryHeight => prefab.entry.height;
  double get exitHeight => prefab.exit.height;
}
