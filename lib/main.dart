import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app/quick_draw_dash_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ');
    if (details.stack != null) {
      debugPrint(details.stack.toString());
    }
  };

  await _initializeFirebase();
  await _initializeMobileAds();

  runZonedGuarded(
    () {
      runApp(const QuickDrawDashApp());
    },
    (error, stackTrace) {
      debugPrint('Uncaught zone error: ');
      debugPrint(stackTrace.toString());
    },
  );
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (error, stackTrace) {
    debugPrint('Firebase initialization failed: ');
    debugPrint(stackTrace.toString());
  }
}

Future<void> _initializeMobileAds() async {
  try {
    await MobileAds.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('Mobile Ads initialization failed: ');
    debugPrint(stackTrace.toString());
  }
}
