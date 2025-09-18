enum MonetizationProductKind { coinBundle, removeAds, coinMultiplier }

class MonetizationProduct {
  const MonetizationProduct({
    required this.id,
    required this.kind,
    this.coinReward,
    this.coinMultiplier,
    this.multiplierDuration,
  });

  final String id;
  final MonetizationProductKind kind;
  final int? coinReward;
  final double? coinMultiplier;
  final Duration? multiplierDuration;
}

class ProductCatalog {
  static const MonetizationProduct removeAds = MonetizationProduct(
    id: 'quickdrawdash.remove_ads',
    kind: MonetizationProductKind.removeAds,
  );

  static const MonetizationProduct coinsSmall = MonetizationProduct(
    id: 'quickdrawdash.coins.small',
    kind: MonetizationProductKind.coinBundle,
    coinReward: 500,
  );

  static const MonetizationProduct coinsLarge = MonetizationProduct(
    id: 'quickdrawdash.coins.large',
    kind: MonetizationProductKind.coinBundle,
    coinReward: 2500,
  );

  static const MonetizationProduct coinBooster = MonetizationProduct(
    id: 'quickdrawdash.coin.multiplier',
    kind: MonetizationProductKind.coinMultiplier,
    coinMultiplier: 2.0,
    multiplierDuration: Duration(days: 7),
  );

  static const List<MonetizationProduct> catalog = <MonetizationProduct>[
    removeAds,
    coinsSmall,
    coinsLarge,
    coinBooster,
  ];

  static Set<String> get productIds =>
      catalog.map((product) => product.id).toSet();

  static MonetizationProduct? findById(String id) {
    for (final product in catalog) {
      if (product.id == id) {
        return product;
      }
    }
    return null;
  }
}
