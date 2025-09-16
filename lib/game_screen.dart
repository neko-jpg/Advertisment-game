
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

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late final GameProvider _gameProvider;
  bool _isDrawingGestureActive = false;

  @override
  void initState() {
    super.initState();
    _gameProvider = Provider.of<GameProvider>(context, listen: false);

    // Use a post-frame callback to ensure the layout is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final size = MediaQuery.of(context).size;
        _gameProvider.setScreenSize(size);
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer5<GameProvider, LineProvider, ObstacleProvider, CoinProvider, MetaProvider>(
          builder: (context, game, lineProvider, obstacleProvider, coinProvider, metaProvider, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                if (game.screenSize != size) {
                  game.setScreenSize(size);
                }

                final halfWidth = size.width * 0.5;
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (details) {
                    if (game.gameState == GameState.ready) {
                      game.startGame();
                      return;
                    }
                    if (game.gameState == GameState.running &&
                        details.localPosition.dx < halfWidth) {
                      game.jump();
                    }
                  },
                  onPanStart: (details) {
                    if (game.gameState != GameState.running) {
                      return;
                    }
                    if (details.localPosition.dx < halfWidth) {
                      _isDrawingGestureActive = false;
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
                        child: CustomPaint(
                          painter: DrawingPainter(
                            playerPosition: Offset(game.playerX, game.playerY),
                            lines: lineProvider.lines,
                            obstacles: obstacleProvider.obstacles,
                            coins: coinProvider.coins,
                            skin: metaProvider.selectedSkin,
                          ),
                        ),
                      ),
                      _buildTutorialOverlay(context, game),
                      _buildGameUI(context, game, lineProvider, metaProvider),
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
    LineProvider lineProvider,
    MetaProvider meta,
  ) {
    switch (game.gameState) {
      case GameState.ready:
        return _buildReadyUI(context, meta);
      case GameState.running:
        return _buildRunningUI(context, game, lineProvider, meta);
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
    LineProvider lineProvider,
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
          Container(
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
                  lineProvider.canStartNewLine ? 'Ink ready' : 'Ink recharging',
                  style: textTheme.bodyLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: lineProvider.inkProgress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      lineProvider.canStartNewLine
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFF97316),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(lineProvider.inkProgress * 100).clamp(0, 100).round()}% charge',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildWalletBanner(context, meta),
        ],
      ),
    );
  }

  Widget _buildGameOverUI(
      BuildContext context, GameProvider game, MetaProvider meta) {
    final adProvider = context.watch<AdProvider>();
    final textTheme = Theme.of(context).textTheme;
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
                        adProvider.maybeShowInterstitial(
                          lastRunDuration: game.lastRunDuration,
                          onClosed: () {
                            game.resetGame();
                            game.startGame();
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
                    if (adProvider.isRewardedAdReady)
                      ElevatedButton.icon(
                        onPressed: () {
                          adProvider.showRewardAd(onReward: () {
                            game.revivePlayer();
                          });
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

  Widget _buildTutorialOverlay(BuildContext context, GameProvider game) {
    if (game.gameState != GameState.running || !game.isTutorialActive) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              bottom: 140,
              child: AnimatedOpacity(
                opacity: game.showJumpHint ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: _buildTutorialBubble(
                  context: context,
                  icon: Icons.touch_app_rounded,
                  text: 'Tap left to jump!',
                  alignment: CrossAxisAlignment.start,
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 140,
              child: AnimatedOpacity(
                opacity: game.showDrawHint ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: _buildTutorialBubble(
                  context: context,
                  icon: Icons.gesture_rounded,
                  text: 'Drag right to draw!',
                  alignment: CrossAxisAlignment.end,
                ),
              ),
            ),
          ],
        ),
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
