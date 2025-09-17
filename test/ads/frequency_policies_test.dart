import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/ads/frequency_policies.dart';

void main() {
  test('requires minimum game overs before showing ad', () {
    final controller = AdFrequencyController(
      const [GameOverIntervalPolicy(minimumGameOvers: 3)],
    );

    final context = AdRequestContext(
      trigger: AdTrigger.gameOver,
      elapsedSinceSessionStart: const Duration(seconds: 120),
      elapsedSinceLastInterstitial: const Duration(minutes: 5),
      gameOversSinceLastAd: 2,
      totalGameOvers: 2,
      timeSinceLastGameOver: const Duration(seconds: 1),
    );

    expect(controller.canShow(context), isFalse);

    final readyContext = context.copyWith(gameOversSinceLastAd: 3);
    expect(controller.canShow(readyContext), isTrue);
  });

  test('enforces cooldown and session delay', () {
    final controller = AdFrequencyController(
      const [
        SessionDelayPolicy(delay: Duration(seconds: 15)),
        CooldownPolicy(cooldown: Duration(seconds: 30)),
      ],
    );

    final initialContext = AdRequestContext(
      trigger: AdTrigger.gameOver,
      elapsedSinceSessionStart: const Duration(seconds: 10),
      elapsedSinceLastInterstitial: const Duration(seconds: 5),
      gameOversSinceLastAd: 5,
      totalGameOvers: 5,
      timeSinceLastGameOver: const Duration(seconds: 2),
    );

    expect(controller.canShow(initialContext), isFalse);

    final afterDelay = AdRequestContext(
      trigger: AdTrigger.gameOver,
      elapsedSinceSessionStart: const Duration(seconds: 25),
      elapsedSinceLastInterstitial: const Duration(seconds: 40),
      gameOversSinceLastAd: 5,
      totalGameOvers: 5,
      timeSinceLastGameOver: const Duration(seconds: 2),
    );

    expect(controller.canShow(afterDelay), isTrue);
  });
}
