import 'dart:math' as math;

import '../models/content_models.dart';
import 'chunk_models.dart';

/// Generates a stream of pre-authored chunks that seamlessly stitch together
/// based on connector compatibility, theme, and difficulty requirements.
class ChunkSpawner {
  ChunkSpawner({
    required List<ChunkPrefab> prefabs,
    VisualTheme initialTheme = VisualTheme.classic,
    double maxHeightDelta = 48,
    int queueLength = 4,
    double despawnBuffer = 160,
    math.Random? random,
  })  : assert(prefabs.isNotEmpty, 'At least one prefab is required'),
        _prefabs = List<ChunkPrefab>.unmodifiable(prefabs),
        _theme = initialTheme,
        _maxHeightDelta = maxHeightDelta,
        _queueLength = queueLength < 1
            ? 1
            : (queueLength > 8 ? 8 : queueLength),
        _despawnBuffer = despawnBuffer,
        _random = random ?? math.Random();

  final List<ChunkPrefab> _prefabs;
  final double _maxHeightDelta;
  final int _queueLength;
  final double _despawnBuffer;
  final math.Random _random;
  final List<ChunkInstance> _activeChunks = <ChunkInstance>[];

  VisualTheme _theme;
  double _currentDifficulty = 0.0;

  /// Currently active chunk instances ordered from oldest to newest.
  List<ChunkInstance> get activeChunks => List<ChunkInstance>.unmodifiable(_activeChunks);

  VisualTheme get theme => _theme;
  double get currentDifficulty => _currentDifficulty;

  /// Updates the dynamic difficulty value used when selecting future chunks.
  void updateDifficulty(double difficulty) {
    _currentDifficulty = difficulty.clamp(0.0, 1.0).toDouble();
  }

  /// Changes the active environment theme. Already spawned chunks remain as-is
  /// but future selections will filter by the new theme.
  void setTheme(VisualTheme theme) {
    _theme = theme;
  }

  /// Clears existing chunks and fills the queue starting from [startX].
  void initialize({ChunkPrefab? startingChunk, double startX = 0}) {
    _activeChunks.clear();
    final ChunkPrefab starter = startingChunk ?? _selectStarter();
    _activeChunks.add(ChunkInstance(prefab: starter, startX: startX));
    _fillQueue();
  }

  /// Removes consumed chunks and keeps the queue populated.
  void advance(double playerX) {
    if (_activeChunks.isEmpty) {
      return;
    }
    var removed = false;
    while (_activeChunks.isNotEmpty) {
      final chunk = _activeChunks.first;
      final shouldRemove = playerX - chunk.endX > _despawnBuffer;
      if (!shouldRemove) {
        break;
      }
      _activeChunks.removeAt(0);
      removed = true;
    }
    if (removed || _activeChunks.length < _queueLength) {
      _fillQueue();
    }
  }

  /// Returns the upcoming chunk (if any) without modifying the queue.
  ChunkInstance? peekNext() {
    if (_activeChunks.length <= 1) {
      return null;
    }
    return _activeChunks[1];
  }

  ChunkPrefab _selectStarter() {
    final starters = _prefabs.where((prefab) =>
        prefab.isStarter &&
        prefab.supportsTheme(_theme) &&
        prefab.supportsDifficulty(_currentDifficulty));
    if (starters.isNotEmpty) {
      return starters.first;
    }
    final fallback = _prefabs.where((prefab) => prefab.isStarter);
    if (fallback.isNotEmpty) {
      return fallback.first;
    }
    throw StateError('No starter chunk available for theme $_theme');
  }

  void _fillQueue() {
    while (_activeChunks.length < _queueLength) {
      final nextPrefab = _selectNextPrefab();
      if (nextPrefab == null) {
        throw StateError(
          'Unable to find compatible chunk after ${_activeChunks.last.prefab.id}',
        );
      }
      final startX = _activeChunks.last.endX;
      _activeChunks.add(ChunkInstance(prefab: nextPrefab, startX: startX));
    }
  }

  ChunkPrefab? _selectNextPrefab() {
    if (_activeChunks.isEmpty) {
      return _selectStarter();
    }
    final previous = _activeChunks.last.prefab;

    ChunkPrefab? pick(List<ChunkPrefab> candidates) {
      if (candidates.isEmpty) {
        return null;
      }
      return candidates[_random.nextInt(candidates.length)];
    }

    final directMatches = _prefabs.where((prefab) {
      if (identical(prefab, previous)) {
        return false;
      }
      if (prefab.isStarter) {
        return false;
      }
      if (!prefab.supportsTheme(_theme)) {
        return false;
      }
      if (!prefab.supportsDifficulty(_currentDifficulty)) {
        return false;
      }
      return previous.exit.isCompatibleWith(
        prefab.entry,
        maxHeightDelta: _maxHeightDelta,
      );
    }).toList();

    final direct = pick(directMatches);
    if (direct != null) {
      return direct;
    }

    final transitionMatches = _prefabs.where((prefab) {
      if (!prefab.isTransition) {
        return false;
      }
      if (!prefab.supportsTheme(_theme)) {
        return false;
      }
      return previous.exit.isCompatibleWith(
        prefab.entry,
        maxHeightDelta: _maxHeightDelta,
      );
    }).toList();

    final transition = pick(transitionMatches);
    if (transition != null) {
      return transition;
    }

    final fallbackMatches = _prefabs.where((prefab) {
      if (!prefab.isFallback) {
        return false;
      }
      return previous.exit.isCompatibleWith(
        prefab.entry,
        maxHeightDelta: _maxHeightDelta,
      );
    }).toList();

    return pick(fallbackMatches);
  }
}

export 'chunk_models.dart';
