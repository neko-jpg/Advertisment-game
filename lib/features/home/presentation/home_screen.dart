import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../ads/ad_manager.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/env.dart';
import '../../../core/config/remote_config_service.dart';
import '../../../core/constants/animation_constants.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../game/audio/sound_controller.dart';
import '../../../game/components/player_skin.dart';
import '../../../game/engine/game_engine.dart';
import '../../../game/models/game_models.dart';
import '../../../game/rendering/drawing_painter.dart';
import '../../../game/state/coin_manager.dart';
import '../../../game/state/line_manager.dart';
import '../../../game/state/meta_state.dart';
import '../../../game/state/obstacle_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final SoundController _soundController;

  @override
  void initState() {
    super.initState();
    final environment = context.read<AppEnvironment>();
    _soundController = SoundController(enableAudio: !environment.isTestBuild);
    WidgetsBinding.instance.addObserver(this);
    unawaited(context.read<AdManager>().initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _soundController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      return;
    }
    final game = Provider.maybeOf<GameProvider>(context, listen: false);
    if (game == null) {
      return;
    }
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        game.handleAppLifecyclePause();
        break;
      case AppLifecycleState.resumed:
        game.handleAppLifecycleResume();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameWidth = MediaQuery.of(context).size.width;

    return MultiProvider(
      providers: [
        Provider<SoundController>.value(value: _soundController),
        ChangeNotifierProxyProvider<RemoteConfigService, MetaProvider>(
          create: (_) => MetaProvider(),
          update: (_, remote, meta) =>
              meta!..applyUpgradeConfig(remote.metaConfig),
        ),
        ChangeNotifierProvider(create: (_) => LineProvider()),
        ChangeNotifierProvider(
          create: (_) => ObstacleProvider(gameWidth: gameWidth),
        ),
        ChangeNotifierProvider(create: (_) => CoinProvider()),
        ChangeNotifierProxyProvider6<
            AdManager,
            LineProvider,
            ObstacleProvider,
            CoinProvider,
            MetaProvider,
            RemoteConfigService,
            GameProvider>(
          create: (context) => GameProvider(
            analytics: context.read<AnalyticsService>(),
            adManager: context.read<AdManager>(),
            lineProvider: context.read<LineProvider>(),
            obstacleProvider: context.read<ObstacleProvider>(),
            coinProvider: context.read<CoinProvider>(),
            metaProvider: context.read<MetaProvider>(),
            remoteConfigProvider: context.read<RemoteConfigService>(),
            soundProvider: context.read<SoundController>(),
            vsync: this,
          ),
          update: (_, ad, line, obstacle, coin, meta, remote, game) =>
              game!..updateDependencies(
                ad,
                line,
                obstacle,
                coin,
                meta,
                remote,
              ),
        ),
      ],
      child: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _InkUiState {
  const _InkUiState({required this.canStartNewLine, required this.inkProgress});

  final bool canStartNewLine;

  final double inkProgress;
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late final GameProvider _gameProvider;

  bool _isDrawingGestureActive = false;

  bool _isOneTapDrawing = false;

  late final AnimationController _ghostHandController;

  late final Animation<double> _ghostHandAnimation;

  double _startButtonScale = 1.0;

  double _missionButtonScale = 1.0;

  Duration _startButtonAnimationDuration =
      AnimationConstants.buttonPressDuration;

  Duration _missionButtonAnimationDuration =
      AnimationConstants.buttonPressDuration;

  @override
  void initState() {
    super.initState();

    _gameProvider = Provider.of<GameProvider>(context, listen: false);

    _ghostHandController = AnimationController(
      vsync: this,

      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _ghostHandAnimation = CurvedAnimation(
      parent: _ghostHandController,

      curve: Curves.easeInOut,
    );

    // Use a post-frame callback to ensure the layout is complete

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final size = MediaQuery.of(context).size;

        _gameProvider.setScreenSize(size);
      }
    });
  }

  @override
  void dispose() {
    _ghostHandController.dispose();

    super.dispose();
  }

  void _setStartButtonPressed(bool pressed) {
    final targetScale = pressed ? AnimationConstants.buttonPressedScale : 1.0;

    final targetDuration =
        pressed
            ? AnimationConstants.buttonPressDuration
            : AnimationConstants.buttonReleaseDuration;

    if (_startButtonScale == targetScale &&
        _startButtonAnimationDuration == targetDuration) {
      return;
    }

    setState(() {
      _startButtonScale = targetScale;

      _startButtonAnimationDuration = targetDuration;
    });
  }

  void _setMissionButtonPressed(bool pressed) {
    final targetScale = pressed ? AnimationConstants.buttonPressedScale : 1.0;

    final targetDuration =
        pressed
            ? AnimationConstants.buttonPressDuration
            : AnimationConstants.buttonReleaseDuration;

    if (_missionButtonScale == targetScale &&
        _missionButtonAnimationDuration == targetDuration) {
      return;
    }

    setState(() {
      _missionButtonScale = targetScale;

      _missionButtonAnimationDuration = targetDuration;
    });
  }

  Future<void> _showSkinShop(BuildContext context) async {
    final rootContext = context;

    await showModalBottomSheet(
      context: context,

      barrierColor: Colors.black.withOpacity(0.7),

      backgroundColor: const Color(0xFF020617),

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),

      builder: (sheetContext) {
        return SafeArea(
          top: false,

          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),

            child: Consumer<MetaProvider>(
              builder: (context, meta, _) {
                if (!meta.isReady) {
                  return const Center(child: CircularProgressIndicator());
                }

                final textTheme = Theme.of(context).textTheme;

                return Column(
                  mainAxisSize: MainAxisSize.min,

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Center(
                      child: Text(
                        'Unlock Skins',

                        style: textTheme.titleLarge?.copyWith(
                          color: Colors.white,

                          fontSize: 24,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Center(child: _buildWalletBanner(context, meta)),

                    const SizedBox(height: 20),

                    SizedBox(
                      height: 320,

                      child: ListView.separated(
                        itemCount: meta.skins.length,

                        shrinkWrap: true,

                        itemBuilder: (itemContext, index) {
                          final skin = meta.skins[index];

                          return _buildSkinTile(
                            rootContext: rootContext,

                            meta: meta,

                            skin: skin,
                          );
                        },

                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showProgressionSheet(
    BuildContext context,

    MetaProvider meta,
  ) async {
    await meta.refreshDailyMissionsIfNeeded();

    await showModalBottomSheet(
      context: context,

      barrierColor: Colors.black.withOpacity(0.7),

      backgroundColor: const Color(0xFF020617),

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),

      builder: (sheetContext) {
        return SafeArea(
          top: false,

          child: Consumer<MetaProvider>(
            builder: (context, meta, _) {
              final missions = meta.dailyMissions;

              final upgrades = meta.upgradeDefinitions;

              final loginState = meta.loginRewardState;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    _buildSheetTitle(context, 'Progress & Rewards'),

                    const SizedBox(height: 16),

                    _buildLoginSection(sheetContext, meta, loginState),

                    const SizedBox(height: 24),

                    _buildMissionSection(sheetContext, missions, meta),

                    const SizedBox(height: 24),

                    _buildUpgradeSection(sheetContext, upgrades, meta),

                    const SizedBox(height: 24),

                    _buildGachaSection(sheetContext, meta),

                    const SizedBox(height: 24),

                    _buildSettingsSection(sheetContext, meta),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSheetTitle(BuildContext context, String text) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Text(
        text,

        style: textTheme.titleLarge?.copyWith(
          color: Colors.white,

          fontSize: 24,
        ),
      ),
    );
  }

  Widget _buildLoginSection(
    BuildContext context,

    MetaProvider meta,

    LoginRewardState? loginState,
  ) {
    final textTheme = Theme.of(context).textTheme;

    final streak = loginState?.streak ?? 0;

    final nextClaim = loginState?.nextClaim;

    final canClaim = meta.canClaimLoginBonus;

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            'Login Bonus',

            style: textTheme.titleMedium?.copyWith(color: Colors.white),
          ),

          const SizedBox(height: 6),

          Text(
            'Streak: $streak day${streak == 1 ? '' : 's'}',

            style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),

          if (nextClaim != null)
            Text(
              canClaim
                  ? 'Bonus ready to claim!'
                  : 'Next in ~${_formatRelativeTime(nextClaim)}',

              style: textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed:
                canClaim
                    ? () async {
                      final reward = await meta.claimLoginBonus();

                      if (!mounted) return;

                      _showSnackMessage(
                        context,

                        'Collected $reward coins from daily login!',
                      );
                    }
                    : null,

            icon: const Icon(Icons.card_giftcard_rounded),

            label: const Text('Claim bonus'),

            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),

              foregroundColor: Colors.white,

              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionSection(
    BuildContext context,

    List<DailyMission> missions,

    MetaProvider meta,
  ) {
    final textTheme = Theme.of(context).textTheme;

    if (missions.isEmpty) {
      return Text(
        'New missions will arrive tomorrow.',

        style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          'Daily Missions',

          style: textTheme.titleMedium?.copyWith(color: Colors.white),
        ),

        const SizedBox(height: 12),

        ...missions.map(
          (mission) => Padding(
            padding: const EdgeInsets.only(bottom: 12),

            child: _buildMissionCard(context, mission, meta),
          ),
        ),
      ],
    );
  }

  Widget _buildMissionCard(
    BuildContext context,

    DailyMission mission,

    MetaProvider meta,
  ) {
    final textTheme = Theme.of(context).textTheme;

    final progress =
        (mission.progress / mission.target).clamp(0.0, 1.0).toDouble();

    final completed = mission.completed;

    final claimed = mission.claimed;

    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            _missionDescription(mission),

            style: textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),

          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(6),

            child: LinearProgressIndicator(
              value: progress,

              minHeight: 6,

              backgroundColor: Colors.white.withOpacity(0.15),

              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFACC15),
              ),
            ),
          ),

          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Text(
                '${mission.progress}/${mission.target} • ${mission.reward} coins',

                style: textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),

              ElevatedButton(
                onPressed:
                    completed && !claimed
                        ? () async {
                          final reward = await meta.claimMissionReward(
                            mission.id,
                          );

                          if (!mounted) return;

                          if (reward > 0) {
                            _showSnackMessage(
                              context,

                              'Mission complete! +$reward coins',
                            );
                          }
                        }
                        : null,

                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),

                  foregroundColor: Colors.white,

                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,

                    vertical: 10,
                  ),
                ),

                child: Text(
                  claimed
                      ? 'Claimed'
                      : completed
                      ? 'Claim'
                      : 'In progress',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _missionDescription(DailyMission mission) {
    switch (mission.type) {
      case MissionType.collectCoins:
        return 'Collect ${mission.target} coins in runs';

      case MissionType.surviveTime:
        return 'Survive for ${mission.target} seconds total';

      case MissionType.drawTime:
        return 'Maintain platforms for ${mission.target} seconds';

      case MissionType.jumpCount:
        return 'Perform ${mission.target} jumps';
    }
  }

  Widget _buildUpgradeSection(
    BuildContext context,

    List<UpgradeDefinition> upgrades,

    MetaProvider meta,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          'Permanent Boosts',

          style: textTheme.titleMedium?.copyWith(color: Colors.white),
        ),

        const SizedBox(height: 12),

        ...upgrades.map(
          (upgrade) => Padding(
            padding: const EdgeInsets.only(bottom: 12),

            child: _buildUpgradeCard(context, upgrade, meta),
          ),
        ),
      ],
    );
  }

  Widget _buildUpgradeCard(
    BuildContext context,

    UpgradeDefinition definition,

    MetaProvider meta,
  ) {
    final textTheme = Theme.of(context).textTheme;

    final level = meta.upgradeLevel(definition.type);

    final maxed = level >= definition.maxLevel;

    final nextDescription =
        maxed ? 'Max level reached' : definition.descriptionBuilder(level + 1);

    final cost = meta.upgradeCost(definition.type);

    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),

      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  definition.displayName,

                  style: textTheme.bodyLarge?.copyWith(color: Colors.white),
                ),

                const SizedBox(height: 6),

                Text(
                  nextDescription,

                  style: textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),

                Text(
                  'Level $level / ${definition.maxLevel}',

                  style: textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          ElevatedButton(
            onPressed:
                maxed || meta.totalCoins < cost
                    ? null
                    : () async {
                      final purchased = await meta.purchaseUpgrade(
                        definition.type,
                      );

                      if (!mounted) return;

                      if (purchased) {
                        _showSnackMessage(
                          context,

                          '${definition.displayName} upgraded!',
                        );
                      }
                    },

            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),

              foregroundColor: Colors.white,

              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),

            child: Text(maxed ? 'MAX' : '$cost'),
          ),
        ],
      ),
    );
  }

  Widget _buildGachaSection(BuildContext context, MetaProvider meta) {
    final textTheme = Theme.of(context).textTheme;

    final adProvider = context.watch<AdManager>();

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            'Lucky Capsule',

            style: textTheme.titleMedium?.copyWith(color: Colors.white),
          ),

          const SizedBox(height: 6),

          Text(
            'Watch an ad or spend coins to roll. Guaranteed rare on the 10th pull.',

            style: textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 12,

            runSpacing: 12,

            children: [
              ElevatedButton.icon(
                onPressed:
                    adProvider.isRewardedAdReady
                        ? () => _triggerGachaWithAd(context, meta)
                        : null,

                icon: const Icon(Icons.play_circle_fill_rounded),

                label: const Text('Free roll (Ad)'),

                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),

                  foregroundColor: Colors.white,

                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,

                    vertical: 14,
                  ),
                ),
              ),

              if (meta.canClaimFreeGacha)
                ElevatedButton.icon(
                  onPressed: () => _triggerFreeGacha(context, meta),

                  icon: const Icon(Icons.card_giftcard_rounded),

                  label: const Text('First roll free'),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),

                    foregroundColor: Colors.white,

                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,

                      vertical: 14,
                    ),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed:
                      meta.totalCoins >= 120
                          ? () => _triggerCoinGacha(context, meta)
                          : null,

                  icon: const Icon(Icons.monetization_on_rounded),

                  label: const Text('Spend 120 coins'),

                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,

                    side: BorderSide(color: Colors.white.withOpacity(0.35)),

                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,

                      vertical: 14,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _triggerGachaWithAd(
    BuildContext context,

    MetaProvider meta,
  ) async {
    final adProvider = context.read<AdManager>();

    if (!adProvider.isRewardedAdReady) {
      _showSnackMessage(context, 'Ad not ready yet.');

      return;
    }

    final sound = context.read<SoundController>();

    adProvider.showRewardedAd(
      placement: 'gacha',
      onUserEarnedReward: () {
        meta.pullGacha(viaAd: true).then((result) {
          if (!mounted) return;

          _showSnackMessage(
            context,
            'Unlocked ${result.displayName}${result.wasGuaranteed ? ' (guaranteed!)' : ''}',
          );
        });
      },
      onAdOpened: () {
        sound.pauseBgmForInterruption();
      },
      onAdClosed: () {
        sound.resumeBgmAfterInterruption();
      },
      onFallback: () {
        if (!mounted) return;
        _showSnackMessage(context, 'Ad unavailable.');
      },
    );
  }

  Future<void> _triggerCoinGacha(
    BuildContext context,

    MetaProvider meta,
  ) async {
    if (meta.totalCoins < 120) {
      _showSnackMessage(context, 'Not enough coins for a roll.');

      return;
    }

    final result = await meta.pullGacha(viaAd: false);

    if (!mounted) return;

    _showSnackMessage(
      context,

      'Unlocked ${result.displayName}${result.wasGuaranteed ? ' (guaranteed!)' : ''}',
    );
  }

  Future<void> _triggerFreeGacha(
    BuildContext context,

    MetaProvider meta,
  ) async {
    final result = await meta.pullGacha(viaAd: false);

    if (!mounted) return;

    _showSnackMessage(
      context,

      'Unlocked ${result.displayName}${result.wasGuaranteed ? ' (guaranteed!)' : ''}',
    );
  }

  void _showSnackMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildSettingsSection(BuildContext context, MetaProvider meta) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            'Comfort Settings',

            style: textTheme.titleMedium?.copyWith(color: Colors.white),
          ),

          SwitchListTile.adaptive(
            value: meta.leftHandedMode,

            onChanged: (value) => meta.updateSettings(leftHanded: value),

            activeColor: const Color(0xFF38BDF8),

            title: const Text('Left-handed controls'),

            subtitle: const Text('Swap jump and draw sides'),
          ),

          SwitchListTile.adaptive(
            value: meta.oneTapMode,

            onChanged: (value) => meta.updateSettings(oneTapMode: value),

            activeColor: const Color(0xFF38BDF8),

            title: const Text('One-tap mode'),

            subtitle: const Text('Tap to jump, hold anywhere to draw'),
          ),

          SwitchListTile.adaptive(
            value: meta.colorBlindMode,

            onChanged: (value) => meta.updateSettings(colorBlindMode: value),

            activeColor: const Color(0xFF38BDF8),

            title: const Text('High contrast colors'),

            subtitle: const Text('Improve obstacle visibility'),
          ),

          SwitchListTile.adaptive(
            value: meta.screenShakeEnabled,

            onChanged: (value) => meta.updateSettings(screenShake: value),

            activeColor: const Color(0xFF38BDF8),

            title: const Text('Screen shake'),

            subtitle: const Text('Reduce to avoid motion sickness'),
          ),

          const SizedBox(height: 12),

          Text(
            'Haptic intensity',

            style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),

          Slider(
            value: meta.hapticStrength,

            onChanged: (value) => meta.updateSettings(hapticStrength: value),

            min: 0,

            max: 1,

            divisions: 10,

            label:
                meta.hapticStrength <= 0.05
                    ? 'Off'
                    : meta.hapticStrength.toStringAsFixed(1),
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();

    final difference = dateTime.difference(now);

    if (difference.isNegative) {
      return 'now';
    }

    if (difference.inHours >= 1) {
      return '${difference.inHours}h';
    }

    return '${difference.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer2<GameProvider, MetaProvider>(
          builder: (context, game, metaProvider, child) {
            final lineProvider = context.read<LineProvider>();

            final obstacleProvider = context.read<ObstacleProvider>();

            final coinProvider = context.read<CoinProvider>();

            final combinedListenable = Listenable.merge([
              lineProvider,

              obstacleProvider,

              coinProvider,

              game.worldListenable,
            ]);

            return LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);

                if (game.screenSize != size) {
                  game.setScreenSize(size);
                }

                if (kDebugMode) {
                  debugPrint(
                    'state=${game.gameState} size=${size.width.toStringAsFixed(1)}x${size.height.toStringAsFixed(1)}',
                  );
                }

                final halfWidth = size.width * 0.5;

                final isLeftHanded = metaProvider.leftHandedMode;

                final oneTapMode = metaProvider.oneTapMode;

                bool isJumpZone(Offset offset) =>
                    isLeftHanded
                        ? offset.dx > halfWidth
                        : offset.dx < halfWidth;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,

                  onTapDown:
                      oneTapMode
                          ? null
                          : (details) {
                            if (game.gameState == GameState.ready) {
                              game.startGame();

                              return;
                            }

                            if (game.gameState == GameState.running &&
                                isJumpZone(details.localPosition)) {
                              game.jump();
                            }
                          },

                  onTapUp:
                      oneTapMode
                          ? (_) {
                            if (game.gameState == GameState.ready) {
                              game.startGame();
                            } else if (game.gameState == GameState.running) {
                              game.jump();
                            }
                          }
                          : null,

                  onPanStart:
                      oneTapMode
                          ? null
                          : (details) {
                            if (game.gameState != GameState.running) {
                              return;
                            }

                            if (isJumpZone(details.localPosition)) {
                              _isDrawingGestureActive = false;

                              game.jump();

                              return;
                            }

                            final started = lineProvider.startNewLine(
                              details.localPosition,
                            );

                            _isDrawingGestureActive = started;

                            if (started) {
                              game.markLineUsed();

                              HapticFeedback.lightImpact();
                            }
                          },

                  onPanUpdate:
                      oneTapMode
                          ? null
                          : (details) {
                            if (game.gameState != GameState.running) {
                              return;
                            }

                            if (_isDrawingGestureActive &&
                                lineProvider.isDrawing) {
                              lineProvider.addPointToLine(
                                details.localPosition,
                              );
                            } else {
                              _isDrawingGestureActive = false;
                            }
                          },

                  onPanEnd:
                      oneTapMode
                          ? null
                          : (_) {
                            if (_isDrawingGestureActive ||
                                lineProvider.isDrawing) {
                              _isDrawingGestureActive = false;

                              lineProvider.endCurrentLine();
                            }
                          },

                  onPanCancel:
                      oneTapMode
                          ? null
                          : () {
                            if (_isDrawingGestureActive ||
                                lineProvider.isDrawing) {
                              _isDrawingGestureActive = false;

                              lineProvider.endCurrentLine();
                            }
                          },

                  onLongPressStart:
                      oneTapMode
                          ? (details) {
                            if (game.gameState != GameState.running) {
                              return;
                            }

                            final started = lineProvider.startNewLine(
                              details.localPosition,
                            );

                            _isOneTapDrawing = started;

                            if (started) {
                              game.markLineUsed();

                              HapticFeedback.lightImpact();
                            }
                          }
                          : null,

                  onLongPressMoveUpdate:
                      oneTapMode
                          ? (details) {
                            if (!_isOneTapDrawing ||
                                game.gameState != GameState.running) {
                              return;
                            }

                            lineProvider.addPointToLine(details.localPosition);
                          }
                          : null,

                  onLongPressEnd:
                      oneTapMode
                          ? (_) {
                            if (_isOneTapDrawing || lineProvider.isDrawing) {
                              _isOneTapDrawing = false;

                              lineProvider.endCurrentLine();
                            }
                          }
                          : null,

                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: combinedListenable,

                            builder: (context, _) {
                              return CustomPaint(
                                painter: DrawingPainter(
                                  playerPosition: Offset(
                                    game.playerX,

                                    game.playerY,
                                  ),

                                  lines: lineProvider.lines,

                                  obstacles: obstacleProvider.obstacles,

                                  coins: coinProvider.coins,

                                  skin: metaProvider.selectedSkin,

                                  isRestWindow: game.isRestWindow,

                                  colorBlindFriendly:
                                      metaProvider.colorBlindMode,

                                  elapsedMs: game.elapsedRunMs,

                                  scrollSpeed: obstacleProvider.speed,

                                  frameId: game.worldFrame,

                                  lineSignature: lineProvider.signature,
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      if (kDebugMode)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              color: Colors.red.withOpacity(0.05),
                            ),
                          ),
                        ),

                      _buildTutorialOverlay(context, game, metaProvider),

                      _buildToastOverlay(context, game),

                      _buildGameUI(context, game, metaProvider),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildGameUI(
    BuildContext context,

    GameProvider game,

    MetaProvider meta,
  ) {
    switch (game.gameState) {
      case GameState.ready:
        return _buildReadyUI(context, meta);

      case GameState.running:
        return _buildRunningUI(context, game, meta);

      case GameState.dead:
        return _buildGameOverUI(context, game, meta);

      case GameState.result:
        return const SizedBox.shrink();
    }
  }

  Widget _buildToastOverlay(BuildContext context, GameProvider game) {
    final textTheme = Theme.of(context).textTheme;

    return ValueListenableBuilder<GameToast?>(
      valueListenable: game.toastListenable,

      builder: (context, toast, _) {
        if (toast == null) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: 32,

          left: 16,

          right: 16,

          child: AnimatedOpacity(
            opacity: toast == null ? 0 : 1,

            duration: const Duration(milliseconds: 180),

            child: Align(
              alignment: Alignment.topCenter,

              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,

                  vertical: 12,
                ),

                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),

                  borderRadius: BorderRadius.circular(20),

                  border: Border.all(color: toast.color.withOpacity(0.4)),

                  boxShadow: [
                    BoxShadow(
                      color: toast.color.withOpacity(0.2),

                      blurRadius: 18,

                      offset: const Offset(0, 8),
                    ),
                  ],
                ),

                child: Row(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Icon(toast.icon, color: toast.color, size: 22),

                    const SizedBox(width: 10),

                    Text(
                      toast.message,

                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white,

                        fontWeight: FontWeight.w600,

                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReadyUI(BuildContext context, MetaProvider meta) {
    final textTheme = Theme.of(context).textTheme;

    return Positioned.fill(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32),

        color: Colors.black.withOpacity(0.25),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Text(
              'Quick Draw Dash',

              textAlign: TextAlign.center,

              style: textTheme.titleLarge?.copyWith(
                color: Colors.white,

                fontSize: 32,

                letterSpacing: 1.4,
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Tap the left side to leap, drag on the right to sketch platforms, and race for the highest score.',

              textAlign: TextAlign.center,

              style: textTheme.bodyLarge?.copyWith(
                color: Colors.white70,

                height: 1.5,
              ),
            ),

            const SizedBox(height: UiSpacing.heroButtonGap),

            Listener(
              onPointerDown: (_) => _setStartButtonPressed(true),

              onPointerUp: (_) => _setStartButtonPressed(false),

              onPointerCancel: (_) => _setStartButtonPressed(false),

              child: AnimatedScale(
                scale: _startButtonScale,

                duration: _startButtonAnimationDuration,

                curve: Curves.easeOutBack,

                child: ElevatedButton.icon(
                  onPressed: () {
                    context.read<SoundController>().playJumpSfx();

                    _gameProvider.startGame();

                    Future.delayed(
                      AnimationConstants.buttonScaleResetDelay,

                      () {
                        if (mounted) {
                          _setStartButtonPressed(false);
                        }
                      },
                    );
                  },

                  icon: const Icon(Icons.play_arrow_rounded, size: 26),

                  label: const Text('START RUN'),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: UiColors.primaryAction,

                    foregroundColor: Colors.white,

                    padding: const EdgeInsets.symmetric(
                      horizontal: UiDimensions.primaryButtonHorizontalPadding,

                      vertical: UiDimensions.primaryButtonVerticalPadding,
                    ),

                    textStyle: textTheme.titleMedium?.copyWith(
                      letterSpacing: 1.2,
                    ),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        UiDimensions.primaryButtonCornerRadius,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: UiSpacing.heroSecondaryGap),

            Listener(
              onPointerDown: (_) => _setMissionButtonPressed(true),

              onPointerUp: (_) => _setMissionButtonPressed(false),

              onPointerCancel: (_) => _setMissionButtonPressed(false),

              child: AnimatedScale(
                scale: _missionButtonScale,

                duration: _missionButtonAnimationDuration,

                curve: Curves.easeOutBack,

                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<SoundController>().playCoinSfx();

                    _showProgressionSheet(context, meta);

                    Future.delayed(
                      AnimationConstants.buttonScaleResetDelay,

                      () {
                        if (mounted) {
                          _setMissionButtonPressed(false);
                        }
                      },
                    );
                  },

                  icon: const Icon(Icons.flag_rounded),

                  label: const Text('MISSIONS & BOOSTS'),

                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,

                    side: BorderSide(
                      color: UiColors.secondaryActionBorder.withOpacity(0.35),

                      width: UiDimensions.secondaryButtonBorderWidth,
                    ),

                    padding: const EdgeInsets.symmetric(
                      horizontal: UiDimensions.secondaryButtonHorizontalPadding,

                      vertical: UiDimensions.secondaryButtonVerticalPadding,
                    ),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        UiDimensions.secondaryButtonCornerRadius,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            _buildWalletBanner(context, meta),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () {
                _showSkinShop(context);
              },

              icon: const Icon(Icons.color_lens_rounded),

              label: const Text('CUSTOMIZE'),

              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,

                side: BorderSide(
                  color: Colors.white.withOpacity(0.4),

                  width: 1.4,
                ),

                padding: const EdgeInsets.symmetric(
                  horizontal: 28,

                  vertical: 16,
                ),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),

            const SizedBox(height: 16),

            _buildReadyAdBoostButton(context, meta),

            const SizedBox(height: 16),

            if (!meta.hasShownLeftHandPrompt)
              _buildLeftHandPromptCard(context, meta),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyAdBoostButton(BuildContext context, MetaProvider meta) {
    return Consumer<AdManager>(
      builder: (context, ad, _) {
        final ready = ad.isRewardedAdReady;

        return ElevatedButton.icon(
          onPressed: ready
              ? () {
                  final sound = context.read<SoundController>();

                  ad.showRewardedAd(
                    placement: 'ready_boost',
                    onUserEarnedReward: () {
                      meta.queueRunBoost(
                        const RunBoost(
                          coinMultiplier: 2.0,
                          inkRegenMultiplier: 1.25,
                          duration: Duration(seconds: 30),
                        ),
                      );

                      _showSnackMessage(
                        context,
                        '30s coin boost primed for your next run!',
                      );
                    },
                    onAdOpened: () {
                      sound.pauseBgmForInterruption();
                    },
                    onAdClosed: () {
                      sound.resumeBgmAfterInterruption();
                    },
                    onFallback: () {
                      meta.addCoins(80);
                      if (!mounted) return;
                      _showSnackMessage(
                        context,
                        'Ad unavailable — grabbed 80 coins instead.',
                      );
                    },
                  );
                }
              : null,

          icon: const Icon(Icons.bolt_rounded),

          label: Text(ready ? 'WATCH AD: 30s BOOST' : 'Loading ad bonus…'),

          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF97316),

            foregroundColor: Colors.white,

            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeftHandPromptCard(BuildContext context, MetaProvider meta) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            'Left-handed mode available',

            style: textTheme.titleSmall?.copyWith(
              color: Colors.white,

              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Swap jump and draw sides for a more comfortable grip.',

            style: textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    meta.updateSettings(leftHanded: true);

                    meta.markLeftHandPromptSeen();

                    _showSnackMessage(context, 'Left-handed controls enabled');
                  },

                  child: const Text('Enable'),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: TextButton(
                  onPressed: () {
                    meta.markLeftHandPromptSeen();
                  },

                  child: const Text('Maybe later'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdValueLegend(TextTheme textTheme) {
    return Wrap(
      alignment: WrapAlignment.center,

      spacing: 8,

      runSpacing: 8,

      children: [
        _buildLegendChip(
          icon: Icons.favorite_rounded,

          label: 'Revive (best)',

          color: const Color(0xFFF97316),

          textTheme: textTheme,
        ),

        _buildLegendChip(
          icon: Icons.monetization_on_rounded,

          label: 'Coins x2',

          color: const Color(0xFFFACC15),

          textTheme: textTheme,
        ),

        _buildLegendChip(
          icon: Icons.casino_rounded,

          label: 'Gacha roll',

          color: const Color(0xFFA855F7),

          textTheme: textTheme,
        ),
      ],
    );
  }

  Widget _buildLegendChip({
    required IconData icon,

    required String label,

    required Color color,

    required TextTheme textTheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

      decoration: BoxDecoration(
        color: color.withOpacity(0.16),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: color.withOpacity(0.4)),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(icon, size: 18, color: color),

          const SizedBox(width: 6),

          Text(
            label,

            style: textTheme.bodySmall?.copyWith(
              color: Colors.white,

              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningUI(
    BuildContext context,

    GameProvider game,

    MetaProvider meta,
  ) {
    final textTheme = Theme.of(context).textTheme;

    return ValueListenableBuilder<int>(
      valueListenable: game.hudListenable,

      builder: (context, _, __) {
        final remaining = game.nextScoreBonusTarget - game.score;

        final safeRemaining = remaining > 0 ? remaining : 0;

        return Positioned(
          top: 24,

          left: 16,

          right: 16,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,

                  vertical: 14,
                ),

                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.28),

                  borderRadius: BorderRadius.circular(22),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatChip(
                            context: context,

                            icon: Icons.trending_up_rounded,

                            label: 'Score',

                            value: '${game.score}',
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: _buildStatChip(
                            context: context,

                            icon: Icons.monetization_on_rounded,

                            label: 'Coins',

                            value: '${game.coinsCollected}',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Text(
                      safeRemaining == 0
                          ? 'Bonus ready! Cash in at the finish.'
                          : 'Next bonus in $safeRemaining pts (+${game.nextScoreBonusReward} coins)',

                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.white70,

                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Selector<LineProvider, _InkUiState>(
                selector:
                    (_, line) => _InkUiState(
                      canStartNewLine: line.canStartNewLine,

                      inkProgress: line.inkProgress,
                    ),

                builder: (context, inkState, _) {
                  return Container(
                    width: 240,

                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,

                      vertical: 12,
                    ),

                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.24),

                      borderRadius: BorderRadius.circular(18),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          inkState.canStartNewLine
                              ? 'Ink ready'
                              : 'Ink recharging',

                          style: textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 8),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),

                          child: LinearProgressIndicator(
                            value: inkState.inkProgress,

                            minHeight: 8,

                            backgroundColor: Colors.white.withOpacity(0.2),

                            valueColor: AlwaysStoppedAnimation<Color>(
                              inkState.canStartNewLine
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFF97316),
                            ),
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          '${(inkState.inkProgress * 100).clamp(0, 100).round()}% charge',

                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.white70,

                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              if (game.isRestWindow) ...[
                const SizedBox(height: 12),

                _buildRestIndicator(context, game),
              ],

              if (game.isBoostActive) ...[
                const SizedBox(height: 12),

                _buildBoostIndicator(context, game),
              ],

              const SizedBox(height: 12),

              _buildWalletBanner(context, meta),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRestIndicator(BuildContext context, GameProvider game) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.75),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          const Icon(
            Icons.self_improvement_rounded,

            color: Color(0xFF38BDF8),

            size: 22,
          ),

          const SizedBox(width: 10),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                'Rest zone',

                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white,

                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 4),

              SizedBox(
                width: 140,

                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),

                  child: LinearProgressIndicator(
                    value: game.restWindowProgress,

                    minHeight: 6,

                    backgroundColor: Colors.white.withOpacity(0.15),

                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF38BDF8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBoostIndicator(BuildContext context, GameProvider game) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

      decoration: BoxDecoration(
        color: const Color(0xFF1F2937).withOpacity(0.8),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: Colors.orangeAccent.withOpacity(0.35)),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          const Icon(Icons.bolt_rounded, color: Color(0xFFFBBF24), size: 22),

          const SizedBox(width: 10),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                'Boost active',

                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white,

                  fontWeight: FontWeight.w600,
                ),
              ),

              Text(
                '${game.boostRemainingSeconds.ceil()}s of x${game.boostCoinMultiplier.toStringAsFixed(1)} coins & +${((game.boostInkMultiplier - 1) * 100).round()}% ink',

                style: textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverUI(
    BuildContext context,

    GameProvider game,

    MetaProvider meta,
  ) {
    final adProvider = context.watch<AdManager>();

    final textTheme = Theme.of(context).textTheme;

    final canRevive = game.canRevive;

    const coinReviveCost = 150;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.6),

        alignment: Alignment.center,

        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),

          child: Container(
            padding: const EdgeInsets.all(28),

            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.95),

              borderRadius: BorderRadius.circular(28),

              border: Border.all(color: Colors.white.withOpacity(0.08)),

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),

                  blurRadius: 30,

                  offset: const Offset(0, 20),
                ),
              ],
            ),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                Text(
                  'Run Complete',

                  style: textTheme.titleLarge?.copyWith(
                    color: Colors.white,

                    fontSize: 28,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Score: ${game.score}',

                  style: textTheme.bodyLarge?.copyWith(
                    color: Colors.white,

                    fontSize: 18,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Coins collected: ${game.coinsCollected}',

                  style: textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,

                    fontSize: 16,
                  ),
                ),

                if (game.lastRunBonusCoins > 0) ...[
                  const SizedBox(height: 6),

                  Text(
                    'Bonus coins banked: +${game.lastRunBonusCoins}',

                    style: textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF38BDF8),
                    ),
                  ),
                ],

                const SizedBox(height: 6),

                Text(
                  'Next goal: ${game.nextScoreBonusTarget} pts for +${game.nextScoreBonusReward} coins',

                  style: textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),

                const SizedBox(height: 28),

                Wrap(
                  spacing: 12,

                  runSpacing: 12,

                  alignment: WrapAlignment.center,

                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await game.finalizeRun(metaProvider: meta);

                        final sound = context.read<SoundController>();

                        adProvider.maybeShowInterstitial(
                          lastRunDuration: game.lastRunDuration,
                          placement: 'restart',
                          onFinished: () {
                            game.resetGame();
                            game.startGame();
                          },
                          onAdOpened: () {
                            sound.pauseBgmForInterruption();
                          },
                          onAdClosed: () {
                            sound.resumeBgmAfterInterruption();
                          },
                        );
                      },

                      icon: const Icon(Icons.refresh_rounded),

                      label: const Text('RESTART'),

                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),

                        foregroundColor: Colors.white,

                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,

                          vertical: 16,
                        ),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),

                    if (canRevive && adProvider.isRewardedAdReady)
                      ElevatedButton.icon(
                        onPressed: () {
                          final sound = context.read<SoundController>();

                          adProvider.showRewardedAd(
                            placement: 'revive',
                            onUserEarnedReward: () {
                              game.revivePlayer();
                            },
                            onAdOpened: () {
                              sound.pauseBgmForInterruption();
                            },
                            onAdClosed: () {
                              sound.resumeBgmAfterInterruption();
                            },
                            onFallback: () {
                              if (!mounted) return;
                              _showSnackMessage(
                                context,
                                'Ad unavailable — revive failed.',
                              );
                            },
                          );
                        },

                        icon: const Icon(Icons.favorite_rounded),

                        label: const Text('REVIVE'),

                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),

                          foregroundColor: Colors.white,

                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,

                            vertical: 16,
                          ),

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),

                    if (canRevive)
                      OutlinedButton.icon(
                        onPressed:
                            meta.totalCoins >= coinReviveCost
                                ? () async {
                                  final success = await meta.spendCoins(
                                    coinReviveCost,
                                  );

                                  if (success) {
                                    game.revivePlayer();

                                    _showSnackMessage(
                                      context,

                                      'Spent $coinReviveCost coins to revive!',
                                    );
                                  }
                                }
                                : null,

                        icon: const Icon(Icons.bolt_rounded),

                        label: Text('Revive ($coinReviveCost)'),

                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,

                          side: BorderSide(
                            color: Colors.white.withOpacity(0.35),
                          ),

                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,

                            vertical: 16,
                          ),

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                _buildAdValueLegend(textTheme),

                const SizedBox(height: 16),

                TextButton(
                  onPressed: () async {
                    await game.finalizeRun(metaProvider: meta);

                    game.resetGame();
                  },

                  child: const Text('Return to menu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletBanner(BuildContext context, MetaProvider meta) {
    final textTheme = Theme.of(context).textTheme;

    final walletText = meta.isReady ? '${meta.totalCoins}' : '…';

    final equippedSkin = meta.isReady ? meta.selectedSkin.name : 'Loading';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),

      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.22),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          const Icon(Icons.savings_rounded, color: Color(0xFFFACC15), size: 26),

          const SizedBox(width: 12),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                'Wallet',

                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white70,

                  letterSpacing: 1.1,
                ),
              ),

              Text(
                walletText,

                style: textTheme.titleMedium?.copyWith(
                  color: Colors.white,

                  fontSize: 20,
                ),
              ),
            ],
          ),

          const SizedBox(width: 18),

          if (meta.isReady)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'Equipped',

                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white70,

                    letterSpacing: 1.1,
                  ),
                ),

                Text(
                  equippedSkin,

                  style: textTheme.titleSmall?.copyWith(
                    color: Colors.white,

                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSkinTile({
    required BuildContext rootContext,

    required MetaProvider meta,

    required PlayerSkin skin,
  }) {
    final owned = meta.isSkinOwned(skin.id);

    final selected = meta.selectedSkin.id == skin.id;

    final theme = Theme.of(rootContext).textTheme;

    final buttonLabel =
        selected
            ? 'Equipped'
            : owned
            ? 'Equip'
            : 'Unlock ${skin.cost}';

    final Color backgroundColor;

    final Color foregroundColor;

    if (selected) {
      backgroundColor = Colors.white24;

      foregroundColor = Colors.white;
    } else if (!owned) {
      backgroundColor = const Color(0xFFF97316);

      foregroundColor = Colors.black;
    } else {
      backgroundColor = const Color(0xFF38BDF8);

      foregroundColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),

        borderRadius: BorderRadius.circular(20),

        border: Border.all(
          color:
              selected
                  ? const Color(0xFF38BDF8)
                  : Colors.white.withOpacity(0.08),

          width: selected ? 2 : 1,
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 54,

            height: 54,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              gradient: LinearGradient(
                colors: [skin.primaryColor, skin.secondaryColor],
              ),

              boxShadow: [
                BoxShadow(
                  color: skin.auraColor.withOpacity(0.45),

                  blurRadius: 14,

                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  skin.name,

                  style: theme.titleMedium?.copyWith(
                    color: Colors.white,

                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  owned
                      ? (selected ? 'Currently equipped' : 'Unlocked')
                      : 'Cost: ${skin.cost} coins',

                  style: theme.bodySmall?.copyWith(
                    color: owned ? Colors.greenAccent : Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          ElevatedButton(
            onPressed:
                selected
                    ? null
                    : () async {
                      if (!owned) {
                        final success = await meta.purchaseSkin(skin);

                        if (!success) {
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Not enough coins to unlock this skin.',
                              ),

                              behavior: SnackBarBehavior.floating,
                            ),
                          );

                          return;
                        } else {
                          ScaffoldMessenger.of(rootContext).showSnackBar(
                            SnackBar(
                              content: Text('${skin.name} unlocked!'),

                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }

                      await meta.selectSkin(skin);
                    },

            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,

              foregroundColor: foregroundColor,

              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),

              textStyle: theme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),

            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialOverlay(
    BuildContext context,

    GameProvider game,

    MetaProvider meta,
  ) {
    if (game.gameState != GameState.running || !game.isTutorialActive) {
      return const SizedBox.shrink();
    }

    final isLeftHanded = meta.leftHandedMode;

    final jumpLabel = isLeftHanded ? 'Tap right to jump!' : 'Tap left to jump!';

    final drawLabel =
        isLeftHanded ? 'Drag left to draw!' : 'Drag right to draw!';

    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),

        child: Stack(
          children: [
            Positioned(
              left: isLeftHanded ? null : 0,

              right: isLeftHanded ? 0 : null,

              bottom: 140,

              child: AnimatedOpacity(
                opacity: game.showJumpHint ? 1 : 0,

                duration: const Duration(milliseconds: 250),

                child: Column(
                  crossAxisAlignment:
                      isLeftHanded
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,

                  children: [
                    _buildTutorialBubble(
                      context: context,

                      icon: Icons.touch_app_rounded,

                      text: jumpLabel,

                      alignment:
                          isLeftHanded
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                    ),

                    const SizedBox(height: 12),

                    _buildGhostHand(forJump: true, leftHanded: isLeftHanded),
                  ],
                ),
              ),
            ),

            Positioned(
              left: isLeftHanded ? 0 : null,

              right: isLeftHanded ? null : 0,

              bottom: 140,

              child: AnimatedOpacity(
                opacity: game.showDrawHint ? 1 : 0,

                duration: const Duration(milliseconds: 250),

                child: Column(
                  crossAxisAlignment:
                      isLeftHanded
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,

                  children: [
                    _buildTutorialBubble(
                      context: context,

                      icon: Icons.gesture_rounded,

                      text: drawLabel,

                      alignment:
                          isLeftHanded
                              ? CrossAxisAlignment.start
                              : CrossAxisAlignment.end,
                    ),

                    const SizedBox(height: 12),

                    _buildGhostHand(forJump: false, leftHanded: isLeftHanded),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGhostHand({required bool forJump, required bool leftHanded}) {
    return AnimatedBuilder(
      animation: _ghostHandAnimation,

      builder: (context, child) {
        final verticalShift =
            forJump ? -28.0 * _ghostHandAnimation.value : -12.0;

        final horizontalShift =
            forJump
                ? 0.0
                : (leftHanded ? -40.0 : 40.0) * _ghostHandAnimation.value;

        return Transform.translate(
          offset: Offset(horizontalShift, verticalShift),

          child: child,
        );
      },

      child: Icon(
        forJump ? Icons.touch_app_rounded : Icons.gesture_rounded,

        color: Colors.white.withOpacity(0.85),

        size: 42,
      ),
    );
  }

  Widget _buildTutorialBubble({
    required BuildContext context,

    required IconData icon,

    required String text,

    required CrossAxisAlignment alignment,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),

      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,

        crossAxisAlignment: alignment,

        children: [
          Icon(icon, color: Colors.white, size: 22),

          const SizedBox(height: 8),

          Text(
            text,

            style: textTheme.bodyMedium?.copyWith(
              color: Colors.white,

              fontWeight: FontWeight.w600,

              letterSpacing: 1.05,
            ),

            textAlign:
                alignment == CrossAxisAlignment.start
                    ? TextAlign.left
                    : TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required BuildContext context,

    required IconData icon,

    required String label,

    required String value,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),

        borderRadius: BorderRadius.circular(14),
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(icon, color: Colors.white, size: 22),

          const SizedBox(width: 8),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                label.toUpperCase(),

                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white70,

                  letterSpacing: 1.1,
                ),
              ),

              Text(
                value,

                style: textTheme.titleMedium?.copyWith(
                  color: Colors.white,

                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
