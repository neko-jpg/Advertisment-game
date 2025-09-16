import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import 'ad_provider.dart';
import 'analytics_provider.dart';
import 'coin_provider.dart';
import 'game_provider.dart';
import 'game_screen.dart';
import 'line_provider.dart';
import 'meta_provider.dart';
import 'obstacle_provider.dart';
import 'sound_provider.dart';
import 'remote_config_provider.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
  };
  binding.platformDispatcher.onError = (error, stackTrace) {
    debugPrint('ZonedError: $error');
    debugPrintStack(stackTrace: stackTrace);
    return true;
  };
  AnalyticsProvider analytics;
  var firebaseReady = false;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    firebaseReady = Firebase.apps.isNotEmpty;
    analytics = AnalyticsProvider();
  } catch (error, stackTrace) {
    debugPrint('Firebase initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    analytics = AnalyticsProvider.fake();
  }
  try {
    await MobileAds.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('Mobile ads initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(QuickDrawDashApp(analytics: analytics, firebaseReady: firebaseReady));
}

class QuickDrawDashApp extends StatelessWidget {
  const QuickDrawDashApp({
    super.key,
    required this.analytics,
    required this.firebaseReady,
    this.remoteConfigOverride,
    this.soundProviderOverride,
  });

  final AnalyticsProvider analytics;
  final bool firebaseReady;
  final RemoteConfigProvider? remoteConfigOverride;
  final SoundProvider? soundProviderOverride;

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.rubikTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );
    final textTheme = baseTextTheme.copyWith(
      titleLarge: GoogleFonts.orbitron(
        textStyle: baseTextTheme.titleLarge ?? const TextStyle(),
      ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.4),
      titleMedium: GoogleFonts.orbitron(
        textStyle: baseTextTheme.titleMedium ?? const TextStyle(),
      ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.2),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );

    return Provider<AnalyticsProvider>.value(
      value: analytics,
      child: MaterialApp(
        title: 'Quick Draw Dash',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF38BDF8),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF020617),
          textTheme: textTheme,
        ),
        home: GameScreenWrapper(
          firebaseReady: firebaseReady,
          remoteConfigOverride: remoteConfigOverride,
          soundProviderOverride: soundProviderOverride,
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class GameScreenWrapper extends StatefulWidget {
  const GameScreenWrapper({
    super.key,
    required this.firebaseReady,
    this.remoteConfigOverride,
    this.soundProviderOverride,
  });

  final bool firebaseReady;
  final RemoteConfigProvider? remoteConfigOverride;
  final SoundProvider? soundProviderOverride;

  @override
  State<GameScreenWrapper> createState() => _GameScreenWrapperState();
}

class _GameScreenWrapperState extends State<GameScreenWrapper>
    with TickerProviderStateMixin {
  late final RemoteConfigProvider _remoteConfig;
  late final bool _ownsRemoteConfig;
  late final SoundProvider _soundProvider;
  late final bool _ownsSoundProvider;

  @override
  void initState() {
    super.initState();
    final configOverride = widget.remoteConfigOverride;
    if (configOverride != null) {
      _remoteConfig = configOverride;
      _ownsRemoteConfig = false;
    } else {
      _remoteConfig = RemoteConfigProvider(initialize: widget.firebaseReady);
      _ownsRemoteConfig = true;
    }
    final soundOverride = widget.soundProviderOverride;
    if (soundOverride != null) {
      _soundProvider = soundOverride;
      _ownsSoundProvider = false;
    } else {
      _soundProvider = SoundProvider();
      _ownsSoundProvider = true;
    }
  }

  @override
  void dispose() {
    if (_ownsRemoteConfig) {
      _remoteConfig.dispose();
    }
    if (_ownsSoundProvider) {
      _soundProvider.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameWidth = MediaQuery.of(context).size.width;
    return MultiProvider(
      providers: [
        Provider<SoundProvider>.value(value: _soundProvider),
        ChangeNotifierProvider<RemoteConfigProvider>.value(
          value: _remoteConfig,
        ),
        ChangeNotifierProxyProvider<RemoteConfigProvider, MetaProvider>(
          create: (_) => MetaProvider(),
          update:
              (_, remote, meta) => meta!..applyUpgradeConfig(remote.metaConfig),
        ),
        ChangeNotifierProxyProvider<RemoteConfigProvider, AdProvider>(
          create:
              (context) =>
                  AdProvider(analytics: context.read<AnalyticsProvider>()),
          update: (_, remote, ad) => ad!..applyRemoteConfig(remote.adConfig),
        ),
        ChangeNotifierProvider(create: (_) => LineProvider()),
        ChangeNotifierProvider(
          create: (_) => ObstacleProvider(gameWidth: gameWidth),
        ),
        ChangeNotifierProvider(create: (_) => CoinProvider()),
        ChangeNotifierProxyProvider6<
          AdProvider,
          LineProvider,
          ObstacleProvider,
          CoinProvider,
          MetaProvider,
          RemoteConfigProvider,
          GameProvider
        >(
          create:
              (context) => GameProvider(
                analytics: context.read<AnalyticsProvider>(),
                adProvider: context.read<AdProvider>(),
                lineProvider: context.read<LineProvider>(),
                obstacleProvider: context.read<ObstacleProvider>(),
                coinProvider: context.read<CoinProvider>(),
                metaProvider: context.read<MetaProvider>(),
                remoteConfigProvider: context.read<RemoteConfigProvider>(),
                soundProvider: context.read<SoundProvider>(),
                vsync: this,
              ),
          update:
              (_, ad, line, obstacle, coin, meta, remote, game) =>
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
