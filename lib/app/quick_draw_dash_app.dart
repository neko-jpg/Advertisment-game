import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myapp/features/home/presentation/home_screen.dart';
import '../core/analytics/analytics_service.dart';
import '../core/env.dart';
import '../game/audio/sound_controller.dart';
import '../game/state/meta_state.dart';
import '../monetization/storefront_service.dart';
import '../services/ad_service.dart';
import '../services/player_wallet.dart';

class QuickDrawDashApp extends StatelessWidget {
  const QuickDrawDashApp({super.key});

  @override
  Widget build(BuildContext context) {
    final environment = AppEnvironment.resolve();
    AnalyticsService analytics;
    try {
      analytics =
          environment.analyticsEnabled
              ? AnalyticsService()
              : AnalyticsService.fake();
    } catch (_) {
      analytics = AnalyticsService.fake();
    }

    return MultiProvider(
      providers: [
        Provider<AppEnvironment>.value(value: environment),
        Provider<AnalyticsService>.value(value: analytics),
        ChangeNotifierProvider<MetaProvider>(
          create: (_) => MetaProvider(analytics: analytics),
        ),
        ChangeNotifierProvider<PlayerWallet>(
          create: (_) {
            final wallet = PlayerWallet();
            unawaited(wallet.initialize());
            return wallet;
          },
        ),
        ChangeNotifierProxyProvider<PlayerWallet, AdService>(
          create:
              (_) => AdService(environment: environment, analytics: analytics),
          update: (_, wallet, adService) {
            adService ??= AdService(
              environment: environment,
              analytics: analytics,
            );
            adService.syncWallet(wallet);
            if (!adService.isInitialized && !adService.adsDisabled) {
              unawaited(adService.initialize());
            }
            return adService;
          },
        ),
        ChangeNotifierProvider<StorefrontService>(
          create: (context) {
            final wallet = context.read<PlayerWallet>();
            final store = StorefrontService(
              wallet: wallet,
              analytics: analytics,
            );
            unawaited(store.initialize());
            return store;
          },
        ),
        Provider<SoundController>(
          create: (_) => SoundController(),
          dispose: (_, controller) => controller.dispose(),
        ),
      ],
      child: MaterialApp(
        title: 'Quick Draw Dash',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3B82F6),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: Colors.black,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
