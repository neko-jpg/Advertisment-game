import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/app/app.dart';
import 'package:myapp/app/di/injector.dart';
import 'package:myapp/core/analytics/analytics_service.dart';
import 'package:myapp/core/config/remote_config_service.dart';
import 'package:myapp/core/env.dart';
import 'package:myapp/core/logging/logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await serviceLocator.reset();
    final environment = AppEnvironment.resolve().copyWith(
      adsEnabled: false,
      analyticsEnabled: false,
    );
    serviceLocator.registerSingleton<AppEnvironment>(environment);
    serviceLocator.registerLazySingleton<AppLogger>(
      () => AppLogger(environment: environment),
    );

    await configureDependencies(
      analytics: AnalyticsService.fake(),
      firebaseReady: false,
    );
    serviceLocator<RemoteConfigService>().markReadyForTesting();
  });

  testWidgets('renders the Quick Draw Dash start screen', (tester) async {
    final binding = tester.binding;
    binding.window.physicalSizeTestValue = const Size(1080, 1920);
    binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(() {
      binding.window.clearPhysicalSizeTestValue();
      binding.window.clearDevicePixelRatioTestValue();
    });

    await tester.pumpWidget(const QuickDrawDashApp());
    await tester.pumpAndSettle();

    expect(find.text('Quick Draw Dash'), findsOneWidget);
    expect(find.text('START RUN'), findsOneWidget);
  });
}
