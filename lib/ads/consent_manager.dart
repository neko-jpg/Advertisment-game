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
              testIdentifiers: const <String>[],
            )
          : null,
    );
    try {
      final completer = Completer<void>();
      info.requestConsentInfoUpdate(
        parameters,
        () {
          final status = info.getConsentStatus();
          _requiresConsent = status == ConsentStatus.required;
          _nonPersonalizedAds = status != ConsentStatus.obtained;
          info.isConsentFormAvailable().then((isAvailable) {
            if (_requiresConsent && isAvailable) {
              _loadAndShowForm();
            }
          });
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        (FormError error) {
          _logger.warn('Consent update failed', error: error);
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );
      await completer.future;
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
      ConsentForm.loadConsentForm(
        (ConsentForm form) async {
          if (!_requiresConsent) {
            return;
          }
          form.show((FormError? error) {
            if (error != null) {
              _logger.warn('Consent form show failed', error: error);
            }
          });
        },
        (FormError error) {
          _logger.warn('Consent form load failed', error: error);
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
      _nonPersonalizedAds = info.getConsentStatus() != ConsentStatus.obtained;
    }
  }

  AdRequest buildAdRequest() {
    return AdRequest(nonPersonalizedAds: nonPersonalizedAds);
  }
}
