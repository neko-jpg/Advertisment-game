import 'package:flutter/material.dart';

import '../../features/home/presentation/home_screen.dart';

class AppRouter {
  AppRouter();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case HomeRoute.path:
      case null:
        return MaterialPageRoute<void>(
          builder: (_) => const HomeScreen(),
          settings: const RouteSettings(name: HomeRoute.path),
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const HomeScreen(),
          settings: const RouteSettings(name: HomeRoute.path),
        );
    }
  }
}

class HomeRoute {
  static const path = '/';
}
