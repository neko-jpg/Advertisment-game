import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/env.dart';
import '../core/logging/logger.dart';

class ConsentManager {
  ConsentManager({
    required AppEnvironment environment,
    required AppLogger logger,
  })  : _environment = environment,
        _logger = logger;

  final AppEnvironment _environment;
  final AppLogger _logger;

  bool _initialized = false;
  bool _nonPersonalizedAds = false;
  bool _consentGathered = false;
  bool _requiresConsent = false;
  ConsentInformation? _consentInformation;

  bool get initialized => _initialized;
  bool get nonPersonalizedAds =>
      _nonPersonalizedAds || _environment.adUnits.nonPersonalizedAds;
  bool get requiresConsent => _requiresConsent;
  bool get consentGathered => _consentGathered;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _consentInformation = ConsentInformation.instance;
    final info = _consentInformation!;
    final parameters = ConsentRequestParameters(
      consentDebugSettings: _environment.isTestBuild
          ? ConsentDebugSettings(
              debugGeography: DebugGeography.debugGeographyEea,
              testDeviceIds: const <String>[],
            )
          : null,
    );
    try {
      await info.requestConsentInfoUpdate(parameters);
      _requiresConsent = info.consentStatus == ConsentStatus.required;
      if (_requiresConsent && info.isConsentFormAvailable) {
        await _loadAndShowForm();
      }
      _nonPersonalizedAds = info.consentStatus != ConsentStatus.obtained;
      _consentGathered = true;
    } catch (error, stackTrace) {
      _logger.warn('Consent update failed', error: error);
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _initialized = true;
    }
  }

  Future<void> _loadAndShowForm() async {
    try {
      await ConsentForm.loadConsentForm().then(
        (ConsentForm form) async {
          if (!_requiresConsent) {
            return;
          }
          await form.show();
        },
      );
    } catch (error, stackTrace) {
      _logger.warn('Consent form failed to show', error: error);
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> showFormIfRequired() async {
    if (!_requiresConsent) {
      return;
    }
    await _loadAndShowForm();
    final info = _consentInformation;
    if (info != null) {
      _nonPersonalizedAds = info.consentStatus != ConsentStatus.obtained;
    }
  }

  AdRequest buildAdRequest() {
    return AdRequest(nonPersonalizedAds: nonPersonalizedAds);
  }
}
