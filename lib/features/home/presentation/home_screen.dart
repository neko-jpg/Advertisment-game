import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/kpi/session_metrics_tracker.dart';
import '../../../game/game_controller.dart';
import '../../../game/game_painter.dart';
import '../../../game/models.dart';
import '../../../game/audio/sound_controller.dart';
import '../../../game/state/meta_state.dart';
import '../../../game/story/story_fragment.dart';
import '../../../services/ad_service.dart';
import '../../../services/player_wallet.dart';
import '../../store/storefront_sheet.dart';
import '../../../monetization/storefront_service.dart';
import 'meta_progress_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late GameController _controller;
  late SoundController _soundController;
  late AdService _adService;
  late PlayerWallet _wallet;
  late AnalyticsService _analytics;
  late SessionMetricsTracker _sessionMetrics;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _soundController = context.read<SoundController>();
    _adService = context.read<AdService>();
    _wallet = context.read<PlayerWallet>();
    _analytics = context.read<AnalyticsService>();
    _sessionMetrics = context.read<SessionMetricsTracker>();
    if (!_sessionMetrics.isInitialized) {
      unawaited(_sessionMetrics.initialize());
    }
    final meta = context.read<MetaProvider>();
    _controller = GameController(
      vsync: this,
      soundController: _soundController,
      adService: _adService,
      analytics: _analytics,
      wallet: _wallet,
      meta: meta,
      sessionMetrics: _sessionMetrics,
    )..initialize();
    if (!_adService.isInitialized) {
      unawaited(_adService.initialize());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _controller.pauseForLifecycle();
        unawaited(_soundController.pauseBgmForInterruption());
        break;
      case AppLifecycleState.resumed:
        _controller.resumeFromLifecycle();
        unawaited(_soundController.resumeBgmAfterInterruption());
        if (!_adService.isInitialized) {
          unawaited(_adService.initialize());
        }
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameController>.value(
      value: _controller,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: const [
              _MonetizationBar(),
              SizedBox(height: 8),
              Expanded(child: _GameViewport()),
              _BannerContainer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameViewport extends StatefulWidget {
  const _GameViewport();

  @override
  State<_GameViewport> createState() => _GameViewportState();
}

class _GameViewportState extends State<_GameViewport> {
  static const double _kJumpZoneRatio = 0.45;
  static const double _kDrawActivationThreshold = 18.0;

  int? _activePointer;
  Offset? _panOrigin;
  bool _lineStarted = false;
  bool _lineStartAttempted = false;
  bool _panInDrawingZone = false;
  bool _pointerLocked = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<GameController>(
      builder: (context, controller, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final Size viewport = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            if (controller.viewport != viewport) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                controller.setViewport(viewport);
              });
            }

            final bool allowInput = controller.phase == GamePhase.running;

            return Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  ignoring: !allowInput,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) =>
                        _handleTapDown(controller, details, viewport),
                    onTapUp: (_) => _handleTapEnd(controller),
                    onTapCancel: () => _handleTapEnd(controller),
                    onPanDown: (details) =>
                        _handlePanDown(controller, details, viewport),
                    onPanStart: (details) =>
                        _handlePanStart(controller, details, viewport),
                    onPanUpdate: (details) =>
                        _handlePanUpdate(controller, details, viewport),
                    onPanCancel: () => _handlePanCancel(controller),
                    onPanEnd: (details) =>
                        _handlePanEnd(controller, details),
                    child: AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: GamePainter(
                            playerPosition: controller.playerPosition,
                            playerRadius: controller.playerRadius,
                            lines: controller.lines,
                            obstacles: controller.obstacles,
                            coins: controller.coins,
                            landingDust: controller.landingDust,
                            inkLevel: controller.inkLevel,
                            groundY: controller.groundY,
                            elapsed:
                                DateTime.now().millisecondsSinceEpoch / 1000,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 28,
                  child: const _InkPalette(),
                ),
                const _HudOverlay(),
                if (!controller.tutorialCompleted &&
                    controller.phase == GamePhase.running)
                  _TutorialCoach(stage: controller.tutorialStage),
                if (controller.phase == GamePhase.ready)
                  _ReadyOverlay(
                    stage: controller.tutorialStage,
                    tutorialCompleted: controller.tutorialCompleted,
                  ),
                if (controller.phase == GamePhase.gameOver)
                  const _GameOverOverlay(),
                const _StoryFragmentOverlay(),
              ],
            );
          },
        );
      },
    );
  }

  void _handleTapDown(
    GameController controller,
    TapDownDetails details,
    Size viewport,
  ) {
    if (_pointerLocked) {
      return;
    }
    _pointerLocked = true;
    if (controller.phase == GamePhase.ready) {
      controller.startGame();
      return;
    }
    if (controller.phase != GamePhase.running) {
      return;
    }
    if (details.localPosition.dx < viewport.width * _kJumpZoneRatio) {
      controller.jump();
    }
  }

  void _handleTapEnd(GameController controller) {
    if (_lineStarted) {
      controller.endLine();
    }
    _resetPointerTracking();
  }

  void _handlePanDown(
    GameController controller,
    DragDownDetails details,
    Size viewport,
  ) {
    if (_activePointer != null && details.pointer != _activePointer) {
      return;
    }
    _pointerLocked = true;
    _activePointer = details.pointer;
    _panOrigin = details.localPosition;
    _lineStarted = false;
    _lineStartAttempted = false;
    _panInDrawingZone =
        details.localPosition.dx >= viewport.width * _kJumpZoneRatio;
  }

  void _handlePanStart(
    GameController controller,
    DragStartDetails details,
    Size viewport,
  ) {
    if (_activePointer != null && details.pointer != _activePointer) {
      return;
    }
    if (controller.phase != GamePhase.running) {
      return;
    }
    if (!_panInDrawingZone) {
      controller.jump();
    }
  }

  void _handlePanUpdate(
    GameController controller,
    DragUpdateDetails details,
    Size viewport,
  ) {
    if (_activePointer != null && details.pointer != _activePointer) {
      return;
    }
    if (controller.phase != GamePhase.running) {
      return;
    }
    if (!_panInDrawingZone) {
      return;
    }

    final Offset position = details.localPosition;
    final Offset origin = _panOrigin ?? position;

    if (!_lineStarted) {
      final double travel = (position - origin).distance;
      if (!_lineStartAttempted && travel >= _kDrawActivationThreshold) {
        _lineStartAttempted = true;
        if (controller.startLine(origin)) {
          _lineStarted = true;
          controller.extendLine(position);
        }
      }
      return;
    }

    controller.extendLine(position);
  }

  void _handlePanEnd(GameController controller, DragEndDetails _) {
    if (_lineStarted) {
      controller.endLine();
    }
    _resetPointerTracking();
  }

  void _handlePanCancel(GameController controller) {
    if (_lineStarted) {
      controller.endLine();
    }
    _resetPointerTracking();
  }

  void _resetPointerTracking() {
    _pointerLocked = false;
    _activePointer = null;
    _panOrigin = null;
    _lineStarted = false;
    _lineStartAttempted = false;
    _panInDrawingZone = false;
  }
}

class _HudOverlay extends StatelessWidget {
  const _HudOverlay();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final theme = Theme.of(context);

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _HudChip(
                    label: 'SCORE',
                    value: controller.score.toString().padLeft(3, '0'),
                  ),
                  _HudChip(
                    label: 'COINS',
                    value: controller.coinsCollected.toString().padLeft(2, '0'),
                  ),
                  _HudChip(
                    label: 'BEST',
                    value: controller.bestScore.toString().padLeft(3, '0'),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'Tap left to jump - drag right to draw ink trails',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                  letterSpacing: 0.6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white70,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InkPalette extends StatelessWidget {
  const _InkPalette();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final meta = context.watch<MetaProvider>();
    final List<InkType> types = meta.unlockedInkTypes;
    if (types.length <= 1) {
      return const SizedBox.shrink();
    }
    final bool interactive = controller.phase == GamePhase.running ||
        controller.phase == GamePhase.ready;
    final double opacity = interactive ? 1.0 : 0.35;

    return IgnorePointer(
      ignoring: !interactive,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 200),
        child: Material(
          color: Colors.black.withOpacity(0.38),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final type in types)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _InkTypeChip(
                      type: type,
                      selected: controller.activeInkType == type,
                      onSelected: () {
                        context.read<GameController>().setInkType(type);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InkTypeChip extends StatelessWidget {
  const _InkTypeChip({
    required this.type,
    required this.selected,
    required this.onSelected,
  });

  final InkType type;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final InkMaterial material = type.material;
    final Color accent = material.color;
    final IconData icon = _iconForType(type);

    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.32) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? accent : Colors.white24,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.32),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : accent.withOpacity(0.9),
            ),
            const SizedBox(width: 6),
            Text(
              material.displayName,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconForType(InkType type) {
    switch (type) {
      case InkType.bouncy:
        return Icons.flip;
      case InkType.turbo:
        return Icons.speed;
      case InkType.sticky:
        return Icons.grain;
      case InkType.standard:
      default:
        return Icons.brush;
    }
  }
}

class _ReadyOverlay extends StatelessWidget {
  const _ReadyOverlay({required this.stage, required this.tutorialCompleted});

  final TutorialStage stage;
  final bool tutorialCompleted;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<GameController>();
    final theme = Theme.of(context);
    final bool tutorialActive =
        !tutorialCompleted && stage != TutorialStage.complete;

    String title;
    String subtitle;
    final List<_OverlayTip> tips = <_OverlayTip>[];
    const int totalSteps = 3;
    final int stepNumber = switch (stage) {
      TutorialStage.jump => 1,
      TutorialStage.draw => 2,
      TutorialStage.coin => 3,
      _ => 0,
    };

    if (!tutorialActive) {
      title = 'Quick Draw Dash';
      subtitle =
          'Sketch glowing ink ramps on the right to sail over danger. Tap the left side to vault obstacles. Collect coins to unlock upgrades.';
    } else {
      switch (stage) {
        case TutorialStage.intro:
          title = 'Welcome to Dash Training';
          subtitle =
              "You'll master three quick moves before the real race begins. Tap start when you're ready.";
          tips
            ..add(
              const _OverlayTip(
                Icons.touch_app,
                'Tap the left side to jump grounded hazards.',
              ),
            )
            ..add(
              const _OverlayTip(
                Icons.gesture,
                'Drag on the right to paint glowing ink ramps.',
              ),
            )
            ..add(
              const _OverlayTip(
                Icons.auto_graph,
                'Glide through coin trails to boost your score.',
              ),
            );
          break;
        case TutorialStage.jump:
          title = 'Step 1  -  Jump';
          subtitle =
              'Tap the left side just before the first obstacle to vault safely.';
          tips
            ..add(
              const _OverlayTip(
                Icons.bolt,
                'Short taps give snappy hops-stay grounded to refill ink.',
              ),
            )
            ..add(
              const _OverlayTip(
                Icons.speed,
                'Jump late to keep momentum as the world speeds up.',
              ),
            );
          break;
        case TutorialStage.draw:
          title = 'Step 2  -  Draw Ramps';
          subtitle =
              'Drag on the right half to sketch a smooth ramp ahead of Dash.';
          tips
            ..add(
              const _OverlayTip(
                Icons.brush,
                'Begin your stroke slightly in front of Dash for a clean launch.',
              ),
            )
            ..add(
              const _OverlayTip(
                Icons.timelapse,
                'Ink fades fast-keep lines short and purposeful.',
              ),
            );
          break;
        case TutorialStage.coin:
          title = 'Step 3  -  Coin Trail';
          subtitle =
              'Ride your ramp through the glowing trail to collect every coin.';
          tips
            ..add(
              const _OverlayTip(
                Icons.stacked_line_chart,
                'Aim your ramp so Dash lands on the ground to recharge ink.',
              ),
            )
            ..add(
              const _OverlayTip(
                Icons.stars,
                'Coins nudge your ink gauge upward-link them for bonus speed.',
              ),
            );
          break;
        case TutorialStage.complete:
        default:
          title = 'Quick Draw Dash';
          subtitle =
              'Sketch glowing ink ramps on the right to sail over danger. Tap the left side to vault obstacles. Collect coins to unlock upgrades.';
      }
    }

    final String buttonLabel =
        tutorialActive
            ? (stage == TutorialStage.intro
                ? 'Start Tutorial Run'
                : 'Resume Tutorial')
            : 'Start Run';

    final double progressValue =
        tutorialActive && stepNumber > 0 ? stepNumber / totalSteps : 0;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.7),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (tutorialActive && stepNumber > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Step $stepNumber of $totalSteps',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white70,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              if (tips.isNotEmpty) ...[
                const SizedBox(height: 20),
                for (final tip in tips)
                  _TutorialListItem(icon: tip.icon, text: tip.label),
              ],
              if (tutorialActive && stepNumber > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progressValue.clamp(0.0, 1.0),
                      minHeight: 8,
                      color: const Color(0xFF38BDF8),
                      backgroundColor: Colors.white.withOpacity(0.12),
                    ),
                  ),
                ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: controller.startGame,
                icon: const Icon(Icons.play_arrow),
                label: Text(buttonLabel),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayTip {
  const _OverlayTip(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _TutorialListItem extends StatelessWidget {
  const _TutorialListItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialCoach extends StatelessWidget {
  const _TutorialCoach({required this.stage});

  final TutorialStage stage;

  @override
  Widget build(BuildContext context) {
    if (stage == TutorialStage.intro || stage == TutorialStage.complete) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    String title;
    String message;
    IconData icon;
    switch (stage) {
      case TutorialStage.jump:
        title = 'Tap left to jump';
        message = 'Time your tap as the first hazard rolls in.';
        icon = Icons.touch_app;
        break;
      case TutorialStage.draw:
        title = 'Drag right to draw';
        message = 'Sketch a small ramp ahead of Dash to lift off.';
        icon = Icons.gesture;
        break;
      case TutorialStage.coin:
        title = 'Follow the coin trail';
        message = 'Ride your ink line through every coin for bonus score.';
        icon = Icons.auto_graph;
        break;
      default:
        return const SizedBox.shrink();
    }
    return Positioned(
      bottom: 96,
      left: 24,
      right: 24,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Container(
          key: ValueKey<TutorialStage>(stage),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.16),
                blurRadius: 14,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonetizationBar extends StatelessWidget {
  const _MonetizationBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wallet = context.watch<PlayerWallet>();
    final controller = context.watch<GameController>();
    final store = context.watch<StorefrontService>();
    final sessionMetrics = context.watch<SessionMetricsTracker>();
    final bool multiplierActive = wallet.coinMultiplier > 1.0;
    final Duration? remaining = wallet.coinMultiplierRemaining;
    final bool adsRemoved = wallet.adsRemoved;
    final bool storeBusy = store.loading || store.initializing;
    final int lastReward = controller.lastRunAwardedCoins;
    final bool showLastReward =
        controller.phase == GamePhase.gameOver && lastReward > 0;
    final bool trackerReady = sessionMetrics.isInitialized;

    final String boostLabel =
        multiplierActive
            ? 'Boost x${wallet.coinMultiplier.toStringAsFixed(1)}' +
                (remaining != null ? ' - ${_formatRemaining(remaining)}' : '')
            : 'Multiplier x1.0';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coins',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${wallet.totalCoins}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          multiplierActive ? Icons.bolt : Icons.bolt_outlined,
                          size: 16,
                          color:
                              multiplierActive
                                  ? Colors.amberAccent
                                  : Colors.white54,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            boostLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  multiplierActive
                                      ? Colors.amberAccent
                                      : Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (adsRemoved)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified,
                              size: 16,
                              color: Colors.lightBlueAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Ads disabled',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.lightBlueAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (showLastReward)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '+$lastReward coins last run',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.greenAccent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed:
                    trackerReady ? () => showMetaProgressSheet(context) : null,
                icon: trackerReady
                    ? const Icon(Icons.insights_outlined)
                    : const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                label: Text(trackerReady ? 'Progress' : 'Loading'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed:
                    storeBusy ? null : () => showStorefrontSheet(context),
                icon:
                    storeBusy
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.storefront_outlined),
                label: Text(storeBusy ? 'Loading' : 'Shop'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRemaining(Duration duration) {
    if (duration.inDays >= 1) {
      return '${duration.inDays}d';
    }
    if (duration.inHours >= 1) {
      return '${duration.inHours}h';
    }
    if (duration.inMinutes >= 1) {
      return '${duration.inMinutes}m';
    }
    return '${duration.inSeconds}s';
  }
}

class _GameOverOverlay extends StatefulWidget {
  const _GameOverOverlay();

  @override
  State<_GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<_GameOverOverlay> {
  bool _reviving = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final adService = context.watch<AdService>();
    final wallet = context.watch<PlayerWallet>();
    final theme = Theme.of(context);
    final canRevive = controller.canRevive && !_reviving;

    final int baseCoins = controller.coinsCollected;
    final int mintedCoins =
        controller.lastRunAwardedCoins > 0
            ? controller.lastRunAwardedCoins
            : baseCoins;
    final bool boosted = mintedCoins > baseCoins && baseCoins > 0;
    final String coinSummary =
        '+$mintedCoins' +
        (boosted ? ' (x${wallet.coinMultiplier.toStringAsFixed(1)})' : '');

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.78),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Run Complete',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 24),
            _SummaryRow(label: 'Score', value: controller.score.toString()),
            _SummaryRow(
              label: 'Time',
              value: _formatDuration(controller.lastRunDuration),
            ),
            _SummaryRow(label: 'Best', value: controller.bestScore.toString()),
            _SummaryRow(label: 'Coins', value: coinSummary),
            if (adService.sessionRuns > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Session runs: ${adService.sessionRuns} | Avg time: ${_formatDuration(adService.averageRunDuration)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 32),
            if (controller.rewardInFlight)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: CircularProgressIndicator.adaptive(),
              )
            else if (canRevive)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    setState(() => _reviving = true);
                    final success = await controller.revive();
                    if (!mounted) return;
                    setState(() => _reviving = false);
                    if (!success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Rewarded ad not available yet. Try again in a moment.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_circle_fill),
                  label: Text(_reviving ? 'Loading...' : 'Watch Ad to Revive'),
                ),
              )
            else if (!adService.hasRewardedAd)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Preparing revive ad...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: controller.startGame,
                child: const Text('Run Again'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: controller.backToMenu,
              child: const Text('Back to Menu'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration <= Duration.zero) {
      return '00:00.0';
    }
    final int minutes = duration.inMinutes;
    final int seconds = duration.inSeconds % 60;
    final int tenths = (duration.inMilliseconds % 1000) ~/ 100;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${tenths}';
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryFragmentOverlay extends StatelessWidget {
  const _StoryFragmentOverlay();

  @override
  Widget build(BuildContext context) {
    return Consumer<MetaProvider>(
      builder: (context, meta, _) {
        final fragment = meta.pendingStoryFragment;
        if (fragment == null) {
          return const SizedBox.shrink();
        }
        return Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.85),
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _StoryFragmentCard(fragment: fragment),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StoryFragmentCard extends StatelessWidget {
  const _StoryFragmentCard({required this.fragment});

  final StoryFragment fragment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111827).withOpacity(0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            Text(
              '断章を解放しました',
              style: textTheme.titleSmall?.copyWith(
                color: Colors.amberAccent,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              fragment.title,
              style: textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              child: Text(
                fragment.body,
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    context.read<MetaProvider>().markStoryFragmentViewed(
                          fragment.id,
                        ),
                child: const Text('走り続ける'),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerContainer extends StatelessWidget {
  const _BannerContainer();

  @override
  Widget build(BuildContext context) {
    final adService = context.watch<AdService>();
    final BannerAd? banner = adService.bannerAd;
    if (banner == null) {
      return const SizedBox(height: 0);
    }
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: banner.size.height.toDouble(),
        width: banner.size.width.toDouble(),
        child: AdWidget(ad: banner),
      ),
    );
  }
}
