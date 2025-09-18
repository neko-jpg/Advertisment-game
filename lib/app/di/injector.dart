import 'package:get_it/get_it.dart';

import '../../ads/ad_manager.dart';
import '../../ads/consent_manager.dart';
import '../router/app_router.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/config/remote_config_service.dart';
import '../../core/env.dart';
import '../../core/kpi/session_metrics_tracker.dart';
import '../../core/logging/logger.dart';

final GetIt serviceLocator = GetIt.instance;

Future<void> configureDependencies({
  required AnalyticsService analytics,
  required bool firebaseReady,
}) async {
  if (!serviceLocator.isRegistered<AppEnvironment>()) {
    serviceLocator.registerSingleton<AppEnvironment>(AppEnvironment.resolve());
  }

  if (!serviceLocator.isRegistered<AppLogger>()) {
    serviceLocator.registerLazySingleton<AppLogger>(
      () => AppLogger(environment: serviceLocator<AppEnvironment>()),
    );
  }

  if (!serviceLocator.isRegistered<AnalyticsService>()) {
    serviceLocator.registerSingleton<AnalyticsService>(analytics);
  } else {
    serviceLocator.unregister<AnalyticsService>();
    serviceLocator.registerSingleton<AnalyticsService>(analytics);
  }

  if (!serviceLocator.isRegistered<SessionMetricsTracker>()) {
    final tracker = SessionMetricsTracker();
    await tracker.initialize();
    serviceLocator.registerSingleton<SessionMetricsTracker>(tracker);
  } else {
    final tracker = serviceLocator<SessionMetricsTracker>();
    if (!tracker.isInitialized) {
      await tracker.initialize();
    }
  }

  if (!serviceLocator.isRegistered<RemoteConfigService>()) {
    serviceLocator.registerLazySingleton<RemoteConfigService>(
      () => RemoteConfigService(initialize: firebaseReady),
    );
  }

  if (!serviceLocator.isRegistered<ConsentManager>()) {
    serviceLocator.registerLazySingleton<ConsentManager>(
      () => ConsentManager(
        environment: serviceLocator<AppEnvironment>(),
        logger: serviceLocator<AppLogger>(),
      ),
    );
  }

  if (!serviceLocator.isRegistered<AdManager>()) {
    serviceLocator.registerLazySingleton<AdManager>(
      () => AdManager(
        analytics: serviceLocator<AnalyticsService>(),
        environment: serviceLocator<AppEnvironment>(),
        consentManager: serviceLocator<ConsentManager>(),
        remoteConfig: serviceLocator<RemoteConfigService>(),
        logger: serviceLocator<AppLogger>(),
      ),
    );
  }

  if (!serviceLocator.isRegistered<AppRouter>()) {
    serviceLocator.registerLazySingleton<AppRouter>(AppRouter.new);
  }
}
