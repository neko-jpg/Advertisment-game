
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'game_provider.dart';
import 'obstacle_provider.dart';
import 'line_provider.dart';
import 'ad_provider.dart';
import 'coin_provider.dart';
import 'sound_provider.dart';
import 'game_screen.dart';
import 'meta_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();

  runApp(const QuickDrawDashApp());
}

class QuickDrawDashApp extends StatelessWidget {
  const QuickDrawDashApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.rubikTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );
    final textTheme = baseTextTheme.copyWith(
      titleLarge: GoogleFonts.orbitron(
        textStyle: baseTextTheme.titleLarge ?? const TextStyle(),
      ).copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
      titleMedium: GoogleFonts.orbitron(
        textStyle: baseTextTheme.titleMedium ?? const TextStyle(),
      ).copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );

    return MaterialApp(
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
      home: const GameScreenWrapper(), // Use a wrapper to provide the providers
      debugShowCheckedModeBanner: false,
    );
  }
}

class GameScreenWrapper extends StatefulWidget {
  const GameScreenWrapper({super.key});

  @override
  State<GameScreenWrapper> createState() => _GameScreenWrapperState();
}

class _GameScreenWrapperState extends State<GameScreenWrapper> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final gameWidth = MediaQuery.of(context).size.width;
    return MultiProvider(
      providers: [
        Provider(create: (_) => SoundProvider()), // Add SoundProvider
        ChangeNotifierProvider(create: (_) => MetaProvider()),
        ChangeNotifierProvider(create: (_) => AdProvider()),
        ChangeNotifierProvider(create: (_) => LineProvider()),
        ChangeNotifierProvider(create: (_) => ObstacleProvider(gameWidth: gameWidth)),
        ChangeNotifierProvider(create: (_) => CoinProvider()),
        ChangeNotifierProxyProvider5<AdProvider, LineProvider, ObstacleProvider, CoinProvider, MetaProvider, GameProvider>(
          create: (context) => GameProvider(
            adProvider: context.read<AdProvider>(),
            lineProvider: context.read<LineProvider>(),
            obstacleProvider: context.read<ObstacleProvider>(),
            coinProvider: context.read<CoinProvider>(),
            metaProvider: context.read<MetaProvider>(),
            soundProvider: context.read<SoundProvider>(),
            vsync: this,
          ),
          update: (_, ad, line, obstacle, coin, meta, game) =>
              game!..updateDependencies(ad, line, obstacle, coin, meta),
        ),
      ],
      child: const GameScreen(),
    );
  }
}
