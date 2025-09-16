import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/ad_provider.dart';
import 'package:myapp/analytics_provider.dart';
import 'package:myapp/coin_provider.dart';
import 'package:myapp/game_models.dart';
import 'package:myapp/game_provider.dart';
import 'package:myapp/line_provider.dart';
import 'package:myapp/meta_provider.dart';
import 'package:myapp/obstacle_provider.dart';
import 'package:myapp/remote_config_provider.dart';
import 'package:myapp/sound_provider.dart';

const DifficultyTuningRemoteConfig _testTuning = DifficultyTuningRemoteConfig(
  defaultSafeWindowPx: 190.0,
  emptyHistorySafeWindowPx: 205.0,
  minSpeedMultiplier: 0.6,
  maxSpeedMultiplier: 1.8,
  minDensityMultiplier: 0.5,
  maxDensityMultiplier: 2.0,
  minCoinMultiplier: 0.6,
  maxCoinMultiplier: 2.0,
  minSafeWindowPx: 120.0,
  maxSafeWindowPx: 280.0,
  longRunDurationSeconds: 40,
  shortRunDurationSeconds: 15,
  consistentRunDurationSeconds: 25,
  highAccidentRate: 0.7,
  lowAccidentRate: 0.3,
  highScoreThreshold: 950,
  lowScoreThreshold: 350,
  longRunSpeedDelta: 0.2,
  longRunDensityDelta: 0.15,
  longRunCoinDelta: -0.1,
  shortRunSpeedDelta: -0.1,
  shortRunDensityDelta: -0.2,
  shortRunCoinDelta: 0.2,
  highAccidentSpeedDelta: -0.2,
  highAccidentDensityDelta: -0.22,
  highAccidentSafeWindowDelta: 70.0,
  highAccidentCoinDelta: 0.12,
  lowAccidentSpeedDelta: 0.1,
  lowAccidentDensityDelta: 0.08,
  highScoreDensityDelta: 0.09,
  highScoreCoinDelta: -0.09,
  lowScoreDensityDelta: -0.12,
  lowScoreCoinDelta: 0.14,
);

Future<MetaProvider> _createMetaProvider() async {
  final provider = MetaProvider();
  var attempts = 0;
  while (!provider.isReady && attempts < 20) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    attempts++;
  }
  return provider;
}

Future<GameProvider> _createGameProvider({
  List<RunStats> runs = const [],
  DifficultyTuningRemoteConfig tuning = _testTuning,
}) async {
  final analytics = AnalyticsProvider.fake();
  final adProvider = AdProvider(analytics: analytics, autoLoad: false);
  final lineProvider = LineProvider();
  final obstacleProvider = ObstacleProvider(gameWidth: 400);
  final coinProvider = CoinProvider();
  final metaProvider = await _createMetaProvider();
  final remoteConfig =
      RemoteConfigProvider(initialize: false)
        ..setDifficultyForTesting(
          const DifficultyRemoteConfig(
            baseSpeedMultiplier: 1.0,
            speedRampIntervalScore: 380,
            speedRampIncrease: 0.35,
            maxSpeedMultiplier: 2.2,
            targetSessionSeconds: 50,
            tutorialSafeWindowMs: 30000,
            emergencyInkFloor: 14,
          ),
        )
        ..setDifficultyTuningForTesting(tuning)
        ..setMetaConfigForTesting(const MetaRemoteConfig(upgradeOverrides: []))
        ..markReadyForTesting();
  final soundProvider = SoundProvider(enableAudio: false);

  final provider = GameProvider(
    analytics: analytics,
    adProvider: adProvider,
    lineProvider: lineProvider,
    obstacleProvider: obstacleProvider,
    coinProvider: coinProvider,
    metaProvider: metaProvider,
    remoteConfigProvider: remoteConfig,
    soundProvider: soundProvider,
    vsync: const TestVSync(),
  );

  if (runs.isNotEmpty) {
    provider.setRecentRunsForTesting(runs);
  }

  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('evaluateDifficulty returns baseline for empty history', () async {
    final provider = await _createGameProvider();
    addTearDown(provider.dispose);

    final tuning = provider.evaluateDifficultyForTesting();
    expect(tuning.speedMultiplier, closeTo(1.0, 0.0001));
    expect(tuning.densityMultiplier, closeTo(1.0, 0.0001));
    expect(tuning.coinMultiplier, closeTo(1.0, 0.0001));
    expect(
      tuning.safeWindowPx,
      closeTo(_testTuning.emptyHistorySafeWindowPx, 0.0001),
    );
  });

  test(
    'long sessions increase difficulty and reduce coin multiplier',
    () async {
      final runs = List<RunStats>.generate(
        3,
        (_) => RunStats(
          duration: const Duration(seconds: 60),
          score: 600,
          coins: 20,
          usedLine: true,
          jumpsPerformed: 12,
          drawTimeMs: 5000,
          accidentDeath: false,
        ),
      );
      final provider = await _createGameProvider(runs: runs);
      addTearDown(provider.dispose);

      final tuning = provider.evaluateDifficultyForTesting();
      final expectedSpeed =
          1.0 +
          _testTuning.longRunSpeedDelta +
          _testTuning.lowAccidentSpeedDelta;
      final expectedDensity =
          1.0 +
          _testTuning.longRunDensityDelta +
          _testTuning.lowAccidentDensityDelta;
      final expectedCoin = 1.0 + _testTuning.longRunCoinDelta;
      expect(tuning.speedMultiplier, closeTo(expectedSpeed, 0.0001));
      expect(tuning.densityMultiplier, closeTo(expectedDensity, 0.0001));
      expect(tuning.coinMultiplier, closeTo(expectedCoin, 0.0001));
      expect(
        tuning.safeWindowPx,
        closeTo(_testTuning.defaultSafeWindowPx, 0.0001),
      );
    },
  );

  test(
    'high accident rate eases difficulty and increases safe window',
    () async {
      final runs = [
        RunStats(
          duration: const Duration(seconds: 50),
          score: 400,
          coins: 15,
          usedLine: true,
          jumpsPerformed: 8,
          drawTimeMs: 3000,
          accidentDeath: true,
        ),
        RunStats(
          duration: const Duration(seconds: 45),
          score: 380,
          coins: 10,
          usedLine: false,
          jumpsPerformed: 6,
          drawTimeMs: 2500,
          accidentDeath: true,
        ),
        RunStats(
          duration: const Duration(seconds: 55),
          score: 420,
          coins: 12,
          usedLine: true,
          jumpsPerformed: 7,
          drawTimeMs: 2600,
          accidentDeath: true,
        ),
      ];
      final provider = await _createGameProvider(runs: runs);
      addTearDown(provider.dispose);

      final tuning = provider.evaluateDifficultyForTesting();
      final expectedSpeed =
          1.0 +
          _testTuning.longRunSpeedDelta +
          _testTuning.highAccidentSpeedDelta;
      final expectedDensity =
          1.0 +
          _testTuning.longRunDensityDelta +
          _testTuning.highAccidentDensityDelta;
      final expectedCoin =
          1.0 +
          _testTuning.longRunCoinDelta +
          _testTuning.highAccidentCoinDelta;
      expect(tuning.speedMultiplier, closeTo(expectedSpeed, 0.0001));
      expect(tuning.densityMultiplier, closeTo(expectedDensity, 0.0001));
      expect(tuning.coinMultiplier, closeTo(expectedCoin, 0.0001));
      expect(
        tuning.safeWindowPx,
        closeTo(
          _testTuning.defaultSafeWindowPx +
              _testTuning.highAccidentSafeWindowDelta,
          0.0001,
        ),
      );
    },
  );
}
