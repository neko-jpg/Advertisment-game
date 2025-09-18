import 'chunk_models.dart';
import '../models/content_models.dart';

/// Catalog of authored chunk prefabs used by the procedural generator.
///
/// The library intentionally keeps the chunks lightweight so that the
/// `ChunkSpawner` can stitch them together at runtime without creating
/// impossible jumps or dead-ends. Each chunk encodes a short gameplay
/// moment (obstacle pattern + collectibles) and exposes entry/exit
/// connectors that describe the relative elevation of the safe path.
class ChunkPrefabLibrary {
  ChunkPrefabLibrary._();

  /// Starter chunk that gives the player a brief runway before the first
  /// challenge. It also acts as a fallback when no other starter is
  /// available for the active theme.
  static final ChunkPrefab starter = ChunkPrefab(
    id: 'starter_plain',
    themes: const <VisualTheme>{},
    length: 320,
    entry: const ChunkEndpoint(profile: ChunkProfiles.start, height: 0),
    exit: const ChunkEndpoint(profile: ChunkProfiles.ground, height: 0),
    difficulty: const DifficultyBracket(min: 0.0, max: 0.35),
    elements: const <ChunkElement>[
      CollectibleElement(
        positionX: 140,
        height: 64,
        rewardType: 'coin_single',
      ),
      ObstacleElement(
        positionX: 220,
        height: 66,
        obstacleType: 'ground_gentle',
      ),
    ],
    isStarter: true,
    isFallback: true,
  );

  static final List<ChunkPrefab> prefabs = <ChunkPrefab>[
    starter,
    ChunkPrefab(
      id: 'ground_sprint_a',
      themes: const <VisualTheme>{},
      length: 420,
      entry: const ChunkEndpoint(profile: ChunkProfiles.ground, height: 0),
      exit: const ChunkEndpoint(profile: ChunkProfiles.ground, height: 0),
      difficulty: const DifficultyBracket(min: 0.0, max: 0.5),
      elements: const <ChunkElement>[
        ObstacleElement(
          positionX: 120,
          height: 62,
          obstacleType: 'ground_gentle',
        ),
        CollectibleElement(
          positionX: 220,
          height: 70,
          rewardType: 'coin_single',
        ),
        ObstacleElement(
          positionX: 320,
          height: 82,
          obstacleType: 'ground',
        ),
      ],
    ),
    ChunkPrefab(
      id: 'ground_speed_lanes',
      themes: const <VisualTheme>{},
      length: 460,
      entry: const ChunkEndpoint(profile: ChunkProfiles.ground, height: 0),
      exit: const ChunkEndpoint(profile: ChunkProfiles.mid, height: 36),
      difficulty: const DifficultyBracket(min: 0.25, max: 0.7),
      elements: const <ChunkElement>[
        ObstacleElement(
          positionX: 140,
          height: 70,
          obstacleType: 'ground',
        ),
        ObstacleElement(
          positionX: 260,
          height: 110,
          obstacleType: 'hopper',
        ),
        CollectibleElement(
          positionX: 360,
          height: 120,
          rewardType: 'coin_column',
        ),
      ],
      isTransition: true,
    ),
    ChunkPrefab(
      id: 'mid_hover_gallery',
      themes: const <VisualTheme>{},
      length: 440,
      entry: const ChunkEndpoint(profile: ChunkProfiles.mid, height: 36),
      exit: const ChunkEndpoint(profile: ChunkProfiles.mid, height: 32),
      difficulty: const DifficultyBracket(min: 0.45, max: 0.85),
      elements: const <ChunkElement>[
        ObstacleElement(
          positionX: 110,
          height: 140,
          obstacleType: 'floater',
        ),
        CollectibleElement(
          positionX: 210,
          height: 150,
          rewardType: 'coin_arc',
        ),
        ObstacleElement(
          positionX: 320,
          height: 150,
          obstacleType: 'moving',
        ),
      ],
    ),
    ChunkPrefab(
      id: 'mid_to_ground_drop',
      themes: const <VisualTheme>{},
      length: 420,
      entry: const ChunkEndpoint(profile: ChunkProfiles.mid, height: 32),
      exit: const ChunkEndpoint(profile: ChunkProfiles.ground, height: 0),
      difficulty: const DifficultyBracket(min: 0.3, max: 0.75),
      elements: const <ChunkElement>[
        ObstacleElement(
          positionX: 160,
          height: 120,
          obstacleType: 'floater',
        ),
        CollectibleElement(
          positionX: 250,
          height: 80,
          rewardType: 'coin_stair_down',
        ),
        ObstacleElement(
          positionX: 340,
          height: 68,
          obstacleType: 'ground',
        ),
      ],
      isTransition: true,
    ),
    ChunkPrefab(
      id: 'ground_spitter_lane',
      themes: const <VisualTheme>{},
      length: 430,
      entry: const ChunkEndpoint(profile: ChunkProfiles.ground, height: 0),
      exit: const ChunkEndpoint(profile: ChunkProfiles.ground, height: 0),
      difficulty: const DifficultyBracket(min: 0.4, max: 0.9),
      elements: const <ChunkElement>[
        ObstacleElement(
          positionX: 130,
          height: 66,
          obstacleType: 'ground',
        ),
        ObstacleElement(
          positionX: 250,
          height: 90,
          obstacleType: 'spitter',
        ),
        CollectibleElement(
          positionX: 340,
          height: 88,
          rewardType: 'coin_column',
        ),
      ],
      isFallback: true,
    ),
    ChunkPrefab(
      id: 'ceiling_scrape',
      themes: const <VisualTheme>{},
      length: 410,
      entry: const ChunkEndpoint(profile: ChunkProfiles.ground, height: 0),
      exit: const ChunkEndpoint(profile: ChunkProfiles.ground, height: 0),
      difficulty: const DifficultyBracket(min: 0.55, max: 1.0),
      elements: const <ChunkElement>[
        ObstacleElement(
          positionX: 150,
          height: 90,
          obstacleType: 'ground',
        ),
        ObstacleElement(
          positionX: 260,
          height: 180,
          obstacleType: 'ceiling',
        ),
        CollectibleElement(
          positionX: 330,
          height: 110,
          rewardType: 'coin_arc',
        ),
      ],
    ),
  ];
}
