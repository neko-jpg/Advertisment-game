
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'game_provider.dart';
import 'ad_provider.dart';
import 'drawing_painter.dart';
import 'line_provider.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late final GameProvider _gameProvider;

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
      body: Consumer<GameProvider>(
        builder: (context, game, child) {
          return GestureDetector(
            onTap: () {
              if (game.gameState == GameState.ready || game.gameState == GameState.dead) {
                // Allow jump to start game or just for fun
              } else {
                game.jump();
              }
            },
            onPanStart: (details) {
              if (game.gameState == GameState.running) {
                context.read<LineProvider>().startNewLine(details.localPosition);
              }
            },
            onPanUpdate: (details) {
              if (game.gameState == GameState.running) {
                context.read<LineProvider>().addPointToLine(details.localPosition);
              }
            },
            child: Stack(
              children: [
                // The main game canvas
                CustomPaint(
                  painter: DrawingPainter(
                    points: context.watch<LineProvider>().lines.expand((line) => line.points).toList(),
                  ),
                  child: Container(),
                ),
                // UI elements on top of the game
                _buildGameUI(game),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGameUI(GameProvider game) {
    switch (game.gameState) {
      case GameState.ready:
        return _buildReadyUI();
      case GameState.running:
        return _buildRunningUI(game);
      case GameState.dead:
        return _buildGameOverUI(game);
      case GameState.result:
        return Container(); // Or a specific result screen
    }
  }

  Widget _buildReadyUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('QUICK DRAW DASH', style: TextStyle(fontSize: 32, fontFamily: 'PressStart2P')),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => _gameProvider.startGame(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            ),
            child: const Text('START GAME', style: TextStyle(fontFamily: 'PressStart2P', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningUI(GameProvider game) {
    return Positioned(
      top: 40,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Score: ${game.score}', style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 16)),
          Row(
            children: [
              const Icon(Icons.monetization_on, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Text('${game.coinsCollected}', style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverUI(GameProvider game) {
    final adProvider = context.watch<AdProvider>();
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(178),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('GAME OVER', style: TextStyle(fontSize: 32, color: Colors.red, fontFamily: 'PressStart2P')),
            const SizedBox(height: 20),
            Text('Score: ${game.score}', style: const TextStyle(fontSize: 20, color: Colors.white, fontFamily: 'PressStart2P')),
            Text('Coins: ${game.coinsCollected}', style: const TextStyle(fontSize: 20, color: Colors.white, fontFamily: 'PressStart2P')),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    adProvider.showInterstitialAdIfNeeded();
                    game.resetGame();
                    game.startGame();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child: const Text('RESTART', style: TextStyle(fontFamily: 'PressStart2P', color: Colors.white)),
                ),
                const SizedBox(width: 20),
                if (adProvider.isRewardedAdReady)
                  ElevatedButton(
                    onPressed: () {
                      adProvider.showRewardAd(onReward: () {
                        game.revivePlayer();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    ),
                    child: const Text('REVIVE', style: TextStyle(fontFamily: 'PressStart2P', color: Colors.white)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
