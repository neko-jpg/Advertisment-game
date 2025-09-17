import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads/ad_manager.dart';
import '../ads/consent_manager.dart';
import '../core/analytics/analytics_service.dart';
import '../core/env.dart';
import '../core/logging/logger.dart';
import 'app.dart';
import 'di/injector.dart';

Future<void> bootstrap() async {
  AppLogger? bootstrapLogger;

  runZonedGuarded(() async {
    final binding = WidgetsFlutterBinding.ensureInitialized();

    final environment = AppEnvironment.resolve();
    if (!serviceLocator.isRegistered<AppEnvironment>()) {
      serviceLocator.registerSingleton<AppEnvironment>(environment);
    }
    if (!serviceLocator.isRegistered<AppLogger>()) {
      serviceLocator.registerLazySingleton<AppLogger>(
        () => AppLogger(environment: environment),
      );
    }
    final logger = serviceLocator<AppLogger>();
    bootstrapLogger = logger;

    FlutterError.onError = (details) {
      logger.error(
        'Flutter error: ${details.exceptionAsString()}',
        stackTrace: details.stack,
      );
    };
    binding.platformDispatcher.onError = (error, stackTrace) {
      logger.error(
        'Platform dispatcher error',
        error: error,
        stackTrace: stackTrace,
      );
      return true;
    };

    AnalyticsService analytics;
    var firebaseReady = false;
    try {
      await Firebase.initializeApp();
      firebaseReady = true;
      analytics = AnalyticsService();
    } catch (error, stackTrace) {
      analytics = AnalyticsService.fake();
      debugPrint('Firebase initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    await configureDependencies(
      analytics: analytics,
      firebaseReady: firebaseReady,
    );

    try {
      await MobileAds.instance.initialize();
    } catch (error, stackTrace) {
      logger.error('Mobile Ads initialization failed', error: error, stackTrace: stackTrace);
    }

    final consentManager = serviceLocator<ConsentManager>();
    await consentManager.initialize();

    final adManager = serviceLocator<AdManager>();
    await adManager.initialize();

    runApp(const QuickDrawDashApp());
  }, (error, stackTrace) {
    final logger = bootstrapLogger ??
        (serviceLocator.isRegistered<AppLogger>()
            ? serviceLocator<AppLogger>()
            : AppLogger(environment: AppEnvironment.resolve()));
    logger.error(
      'Uncaught zone error',
      error: error,
      stackTrace: stackTrace,
    );
  });
}
