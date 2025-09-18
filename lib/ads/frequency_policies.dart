import 'package:flutter/foundation.dart';

enum AdTrigger { gameOver, levelComplete, manual }

@immutable
class AdRequestContext {
  const AdRequestContext({
    required this.trigger,
    required this.elapsedSinceSessionStart,
    required this.elapsedSinceLastInterstitial,
    required this.gameOversSinceLastAd,
    required this.totalGameOvers,
    required this.timeSinceLastGameOver,
  });

  final AdTrigger trigger;
  final Duration elapsedSinceSessionStart;
  final Duration elapsedSinceLastInterstitial;
  final int gameOversSinceLastAd;
  final int totalGameOvers;
  final Duration timeSinceLastGameOver;

  AdRequestContext copyWith({
    AdTrigger? trigger,
    Duration? elapsedSinceSessionStart,
    Duration? elapsedSinceLastInterstitial,
    int? gameOversSinceLastAd,
    int? totalGameOvers,
    Duration? timeSinceLastGameOver,
  }) {
    return AdRequestContext(
      trigger: trigger ?? this.trigger,
      elapsedSinceSessionStart:
          elapsedSinceSessionStart ?? this.elapsedSinceSessionStart,
      elapsedSinceLastInterstitial:
          elapsedSinceLastInterstitial ?? this.elapsedSinceLastInterstitial,
      gameOversSinceLastAd: gameOversSinceLastAd ?? this.gameOversSinceLastAd,
      totalGameOvers: totalGameOvers ?? this.totalGameOvers,
      timeSinceLastGameOver:
          timeSinceLastGameOver ?? this.timeSinceLastGameOver,
    );
  }
}

abstract class AdFrequencyPolicy {
  const AdFrequencyPolicy();

  bool canShow(AdRequestContext context);
}

class GameOverIntervalPolicy extends AdFrequencyPolicy {
  const GameOverIntervalPolicy({required this.minimumGameOvers});

  final int minimumGameOvers;

  @override
  bool canShow(AdRequestContext context) {
    if (context.trigger != AdTrigger.gameOver) {
      return true;
    }
    return context.gameOversSinceLastAd >= minimumGameOvers;
  }
}

class CooldownPolicy extends AdFrequencyPolicy {
  const CooldownPolicy({required this.cooldown});

  final Duration cooldown;

  @override
  bool canShow(AdRequestContext context) {
    return context.elapsedSinceLastInterstitial >= cooldown;
  }
}

class SessionDelayPolicy extends AdFrequencyPolicy {
  const SessionDelayPolicy({required this.delay});

  final Duration delay;

  @override
  bool canShow(AdRequestContext context) {
    if (context.trigger == AdTrigger.manual) {
      return true;
    }
    return context.elapsedSinceSessionStart >= delay;
  }
}

class TimeSinceGameOverPolicy extends AdFrequencyPolicy {
  const TimeSinceGameOverPolicy({required this.minimumDuration});

  final Duration minimumDuration;

  @override
  bool canShow(AdRequestContext context) {
    if (context.trigger != AdTrigger.gameOver) {
      return true;
    }
    return context.timeSinceLastGameOver >= minimumDuration;
  }
}

class AdFrequencyController {
  const AdFrequencyController(this.policies);

  final List<AdFrequencyPolicy> policies;

  AdFrequencyResult evaluate(AdRequestContext context) {
    final List<String> blocked = <String>[];
    for (final policy in policies) {
      if (!policy.canShow(context)) {
        blocked.add(_policyName(policy));
      }
    }
    return AdFrequencyResult(
      allowed: blocked.isEmpty,
      blockedPolicies: blocked,
    );
  }

  bool canShow(AdRequestContext context) => evaluate(context).allowed;

  String _policyName(AdFrequencyPolicy policy) => policy.runtimeType.toString();
}

class AdFrequencyResult {
  const AdFrequencyResult({
    required this.allowed,
    required this.blockedPolicies,
  });

  final bool allowed;
  final List<String> blockedPolicies;
}
