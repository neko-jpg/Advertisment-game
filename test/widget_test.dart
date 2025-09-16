// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/analytics_provider.dart';
import 'package:myapp/main.dart';

void main() {
  testWidgets('renders the Quick Draw Dash start screen', (tester) async {
    await tester.pumpWidget(
      QuickDrawDashApp(
        analytics: AnalyticsProvider.fake(),
      ),
    );

    expect(find.text('Quick Draw Dash'), findsOneWidget);
    expect(find.text('START RUN'), findsOneWidget);
  });
}
