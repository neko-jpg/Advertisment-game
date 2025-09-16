import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/analytics_provider.dart';
import 'package:myapp/main.dart';
import 'package:myapp/remote_config_provider.dart';
import 'package:myapp/sound_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the Quick Draw Dash start screen', (tester) async {
    final binding = tester.binding;
    binding.window.physicalSizeTestValue = const Size(1080, 1920);
    binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(() {
      binding.window.clearPhysicalSizeTestValue();
      binding.window.clearDevicePixelRatioTestValue();
    });

    final remoteConfig = RemoteConfigProvider(initialize: false)
      ..markReadyForTesting();

    await tester.pumpWidget(
      QuickDrawDashApp(
        analytics: AnalyticsProvider.fake(),
        remoteConfigOverride: remoteConfig,
        soundProviderOverride: SoundProvider(enableAudio: false),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Quick Draw Dash'), findsOneWidget);
    expect(find.text('START RUN'), findsOneWidget);
  });
}
