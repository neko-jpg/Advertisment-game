
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'game_provider.dart';
import 'ad_provider.dart';
import 'drawing_painter.dart';
import 'line_provider.dart';
import 'coin_provider.dart';
import 'obstacle_provider.dart';
import 'meta_provider.dart';
import 'player_skin.dart';
import 'game_models.dart';
import 'sound_provider.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _InkUiState {
  const _InkUiState({
    required this.canStartNewLine,
    required this.inkProgress,
  });

  final bool canStartNewLine;
  final double inkProgress;
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late final GameProvider _gameProvider;
  bool _isDrawingGestureActive = false;
  late final AnimationController _ghostHandController;
  late final Animation<double> _ghostHandAnimation;

  @override
  void initState() {
    super.initState();
    _gameProvider = Provider.of<GameProvider>(context, listen: false);

    _ghostHandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _ghostHandAnimation =
        CurvedAnimation(parent: _ghostHandController, curve: Curves.easeInOut);

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
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
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
      BuildContext context, MetaProvider meta) async {
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
            onPressed: canClaim
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
        ...missions.map((mission) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildMissionCard(context, mission, meta),
            )),
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
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFFACC15)),
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
                onPressed: completed && !claimed
                    ? () async {
                        final reward =
                            await meta.claimMissionReward(mission.id);
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Text(claimed
                    ? 'Claimed'
                    : completed
                        ? 'Claim'
                        : 'In progress'),
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
    final nextDescription = maxed
        ? 'Max level reached'
        : definition.descriptionBuilder(level + 1);
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
            onPressed: maxed || meta.totalCoins < cost
                ? null
                : () async {
                    final purchased =
                        await meta.purchaseUpgrade(definition.type);
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
    final adProvider = context.watch<AdProvider>();
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
                onPressed: adProvider.isRewardedAdReady
                    ? () => _triggerGachaWithAd(context, meta)
                    : null,
                icon: const Icon(Icons.play_circle_fill_rounded),
                label: const Text('Free roll (Ad)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
              OutlinedButton.icon(
                onPressed: meta.totalCoins >= 120
                    ? () => _triggerCoinGacha(context, meta)
                    : null,
                icon: const Icon(Icons.monetization_on_rounded),
                label: const Text('Spend 120 coins'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.35)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _triggerGachaWithAd(
      BuildContext context, MetaProvider meta) async {
    final adProvider = context.read<AdProvider>();
    if (!adProvider.isRewardedAdReady) {
      _showSnackMessage(context, 'Ad not ready yet.');
      return;
    }
    final sound = context.read<SoundProvider>();
    adProvider.showRewardAd(
      onReward: () {
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
    );
  }

  Future<void> _triggerCoinGacha(
      BuildContext context, MetaProvider meta) async {
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

  void _showSnackMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
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
            label: meta.hapticStrength <= 0.05
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
            ]);
            return LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                if (game.screenSize != size) {
                  game.setScreenSize(size);
                }

                final halfWidth = size.width * 0.5;
                final isLeftHanded = metaProvider.leftHandedMode;
                bool isJumpZone(Offset offset) =>
                    isLeftHanded ? offset.dx > halfWidth : offset.dx < halfWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (details) {
                    if (game.gameState == GameState.ready) {
                      game.startGame();
                      return;
                    }
                    if (game.gameState == GameState.running &&
                        isJumpZone(details.localPosition)) {
                      game.jump();
                    }
                  },
                  onPanStart: (details) {
                    if (game.gameState != GameState.running) {
                      return;
                    }
                    if (isJumpZone(details.localPosition)) {
                      _isDrawingGestureActive = false;
                      game.jump();
                      return;
                    }
                    final started = lineProvider.startNewLine(details.localPosition);
                    _isDrawingGestureActive = started;
                    if (started) {
                      game.markLineUsed();
                      HapticFeedback.lightImpact();
                    }
                  },
                  onPanUpdate: (details) {
                    if (game.gameState != GameState.running) {
                      return;
                    }
                    if (_isDrawingGestureActive && lineProvider.isDrawing) {
                      lineProvider.addPointToLine(details.localPosition);
                    } else {
                      _isDrawingGestureActive = false;
                    }
                  },
                  onPanEnd: (_) {
                    if (_isDrawingGestureActive || lineProvider.isDrawing) {
                      _isDrawingGestureActive = false;
                      lineProvider.endCurrentLine();
                    }
                  },
                  onPanCancel: (_) {
                    if (_isDrawingGestureActive || lineProvider.isDrawing) {
                      _isDrawingGestureActive = false;
                      lineProvider.endCurrentLine();
                    }
                  },
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: combinedListenable,
                            builder: (context, _) {
                              return CustomPaint(
                                painter: DrawingPainter(
                                  playerPosition: Offset(game.playerX, game.playerY),
                                  lines: lineProvider.lines,
                                  obstacles: obstacleProvider.obstacles,
                                  coins: coinProvider.coins,
                                  skin: metaProvider.selectedSkin,
                                  isRestWindow: game.isRestWindow,
                                  colorBlindFriendly: metaProvider.colorBlindMode,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      _buildTutorialOverlay(context, game, metaProvider),
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
            const SizedBox(height: 36),
            ElevatedButton.icon(
              onPressed: _gameProvider.startGame,
              icon: const Icon(Icons.play_arrow_rounded, size: 26),
              label: const Text('START RUN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                textStyle: textTheme.titleMedium?.copyWith(letterSpacing: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => _showProgressionSheet(context, meta),
              icon: const Icon(Icons.flag_rounded),
              label: const Text('MISSIONS & BOOSTS'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.35), width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
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
                side: BorderSide(color: Colors.white.withOpacity(0.4), width: 1.4),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunningUI(
    BuildContext context,
    GameProvider game,
    MetaProvider meta,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Positioned(
      top: 24,
      left: 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.28),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
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
          ),
          const SizedBox(height: 12),
          Selector<LineProvider, _InkUiState>(
            selector: (_, line) => _InkUiState(
              canStartNewLine: line.canStartNewLine,
              inkProgress: line.inkProgress,
            ),
            builder: (context, inkState, _) {
              return Container(
                width: 240,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.24),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inkState.canStartNewLine ? 'Ink ready' : 'Ink recharging',
                      style: textTheme.bodyLarge?.copyWith(color: Colors.white),
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
          const SizedBox(height: 12),
          _buildWalletBanner(context, meta),
        ],
      ),
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
          const Icon(Icons.self_improvement_rounded,
              color: Color(0xFF38BDF8), size: 22),
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

  Widget _buildGameOverUI(
      BuildContext context, GameProvider game, MetaProvider meta) {
    final adProvider = context.watch<AdProvider>();
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
                const SizedBox(height: 28),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await game.finalizeRun(metaProvider: meta);
                        final sound = context.read<SoundProvider>();
                        adProvider.maybeShowInterstitial(
                          lastRunDuration: game.lastRunDuration,
                          onClosed: () {
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
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                    if (canRevive && adProvider.isRewardedAdReady)
                      ElevatedButton.icon(
                        onPressed: () {
                          final sound = context.read<SoundProvider>();
                          adProvider.showRewardAd(
                            onReward: () {
                              game.revivePlayer();
                            },
                            onAdOpened: () {
                              sound.pauseBgmForInterruption();
                            },
                            onAdClosed: () {
                              sound.resumeBgmAfterInterruption();
                            },
                          );
                        },
                        icon: const Icon(Icons.favorite_rounded),
                        label: const Text('REVIVE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    if (canRevive)
                      OutlinedButton.icon(
                        onPressed: meta.totalCoins >= coinReviveCost
                            ? () async {
                                final success = await meta.spendCoins(coinReviveCost);
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
                              horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                  ],
                ),
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
    final buttonLabel = selected
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
          color: selected ? const Color(0xFF38BDF8) : Colors.white.withOpacity(0.08),
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
            onPressed: selected
                ? null
                : () async {
                    if (!owned) {
                      final success = await meta.purchaseSkin(skin);
                      if (!success) {
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          const SnackBar(
                            content: Text('Not enough coins to unlock this skin.'),
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
              textStyle: theme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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
    final drawLabel = isLeftHanded ? 'Drag left to draw!' : 'Drag right to draw!';
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
                  crossAxisAlignment: isLeftHanded
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    _buildTutorialBubble(
                      context: context,
                      icon: Icons.touch_app_rounded,
                      text: jumpLabel,
                      alignment: isLeftHanded
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
                  crossAxisAlignment: isLeftHanded
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  children: [
                    _buildTutorialBubble(
                      context: context,
                      icon: Icons.gesture_rounded,
                      text: drawLabel,
                      alignment: isLeftHanded
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
        final verticalShift = forJump ? -28.0 * _ghostHandAnimation.value : -12.0;
        final horizontalShift = forJump
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
                alignment == CrossAxisAlignment.start ? TextAlign.left : TextAlign.right,
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
