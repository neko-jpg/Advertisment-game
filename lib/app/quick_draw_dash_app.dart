import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myapp/features/home/presentation/home_screen.dart';
import '../core/analytics/analytics_service.dart';
import '../core/env.dart';
import '../game/audio/sound_controller.dart';
import '../services/ad_service.dart';

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
        ChangeNotifierProvider<AdService>(
          create: (_) {
            final service = AdService(
              environment: environment,
              analytics: analytics,
            );
            unawaited(service.initialize());
            return service;
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
