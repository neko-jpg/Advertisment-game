
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'game_provider.dart';
import 'ad_provider.dart';
import 'drawing_painter.dart';
import 'line_provider.dart';
import 'coin_provider.dart';
import 'obstacle_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer4<GameProvider, LineProvider, ObstacleProvider, CoinProvider>(
          builder: (context, game, lineProvider, obstacleProvider, coinProvider, child) {
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
                          ),
                        ),
                      ),
                      _buildGameUI(context, game, lineProvider),
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
  ) {
    switch (game.gameState) {
      case GameState.ready:
        return _buildReadyUI(context);
      case GameState.running:
        return _buildRunningUI(context, game, lineProvider);
      case GameState.dead:
        return _buildGameOverUI(context, game);
      case GameState.result:
        return const SizedBox.shrink();
    }
  }

  Widget _buildReadyUI(BuildContext context) {
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
          ],
        ),
      ),
    );
  }

  Widget _buildRunningUI(
    BuildContext context,
    GameProvider game,
    LineProvider lineProvider,
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
        ],
      ),
    );
  }

  Widget _buildGameOverUI(BuildContext context, GameProvider game) {
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
                      onPressed: () {
                        adProvider.showInterstitialAdIfNeeded();
                        game.resetGame();
                        game.startGame();
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
                  onPressed: () {
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
