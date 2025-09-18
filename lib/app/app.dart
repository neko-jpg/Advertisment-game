import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ads/ad_manager.dart';
import '../core/analytics/analytics_service.dart';
import '../core/config/remote_config_service.dart';
import '../core/env.dart';
import '../core/kpi/session_metrics_tracker.dart';
import '../core/logging/logger.dart';
import 'di/injector.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class QuickDrawDashApp extends StatelessWidget {
  const QuickDrawDashApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = serviceLocator<AppRouter>();
    final theme = AppTheme.darkTheme();
    return MultiProvider(
      providers: [
        Provider<AnalyticsService>.value(
          value: serviceLocator<AnalyticsService>(),
        ),
        ChangeNotifierProvider<SessionMetricsTracker>.value(
          value: serviceLocator<SessionMetricsTracker>(),
        ),
        ChangeNotifierProvider<RemoteConfigService>.value(
          value: serviceLocator<RemoteConfigService>(),
        ),
        ChangeNotifierProvider<AdManager>.value(
          value: serviceLocator<AdManager>(),
        ),
        Provider<AppEnvironment>.value(
          value: serviceLocator<AppEnvironment>(),
        ),
        Provider<AppLogger>.value(
          value: serviceLocator<AppLogger>(),
        ),
      ],
      child: MaterialApp(
        title: 'Quick Draw Dash',
        navigatorKey: router.navigatorKey,
        onGenerateRoute: router.onGenerateRoute,
        theme: theme,
        initialRoute: HomeRoute.path,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
