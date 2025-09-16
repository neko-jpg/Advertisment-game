import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/game_models.dart';
import 'package:myapp/meta_provider.dart';

Future<MetaProvider> _createProvider() async {
  final provider = MetaProvider();
  var attempts = 0;
  while (!provider.isReady && attempts < 20) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    attempts++;
  }
  return provider;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('addCoins increases total coins', () async {
    final provider = await _createProvider();
    await provider.addCoins(150);
    expect(provider.totalCoins, 150);
  });

  test('spendCoins returns false when balance is insufficient', () async {
    final provider = await _createProvider();
    final canSpend = await provider.spendCoins(40);
    expect(canSpend, isFalse);
    expect(provider.totalCoins, 0);
  });

  test('purchaseUpgrade consumes coins and raises level', () async {
    final provider = await _createProvider();
    await provider.addCoins(500);

    final purchased = await provider.purchaseUpgrade(UpgradeType.inkRegen);
    expect(purchased, isTrue);
    expect(provider.upgradeLevel(UpgradeType.inkRegen), 1);
    expect(provider.totalCoins, 350);
    expect(provider.upgradeCost(UpgradeType.inkRegen), 270);
  });

  test('applyUpgradeConfig overrides upgrade costs', () async {
    final provider = await _createProvider();
    provider.applyUpgradeConfig(
      const MetaRemoteConfig(
        upgradeOverrides: [
          UpgradeCostOverride(
            type: UpgradeType.inkRegen,
            baseCost: 200,
            costGrowth: 25,
            maxLevel: 3,
          ),
        ],
      ),
    );

    expect(provider.upgradeCost(UpgradeType.inkRegen), 200);
    await provider.addCoins(500);
    await provider.purchaseUpgrade(UpgradeType.inkRegen);
    expect(provider.upgradeCost(UpgradeType.inkRegen), 225);
  });
}
