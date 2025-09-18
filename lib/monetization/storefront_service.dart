import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/analytics/analytics_service.dart';
import '../services/player_wallet.dart';
import 'product_catalog.dart';

class StorefrontService extends ChangeNotifier {
  StorefrontService({
    required PlayerWallet wallet,
    required AnalyticsService analytics,
  }) : _wallet = wallet,
       _analytics = analytics;

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final PlayerWallet _wallet;
  final AnalyticsService _analytics;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isAvailable = false;
  bool _initializing = false;
  bool _loading = false;
  bool _restoreInProgress = false;
  String? _errorMessage;
  Map<String, ProductDetails> _products = <String, ProductDetails>{};

  bool get isAvailable => _isAvailable;
  bool get initializing => _initializing;
  bool get loading => _loading;
  bool get restoreInProgress => _restoreInProgress;
  String? get errorMessage => _errorMessage;
  List<ProductDetails> get availableProducts =>
      _products.values.toList()
        ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

  Future<void> initialize() async {
    if (_initializing) {
      return;
    }
    _initializing = true;
    notifyListeners();
    try {
      await _wallet.ensureReady();
      _isAvailable = await _inAppPurchase.isAvailable();
      if (_isAvailable) {
        await _queryProducts();
        _subscription ??= _inAppPurchase.purchaseStream.listen(
          _handlePurchaseUpdates,
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('IAP stream error: $error');
            _errorMessage = 'The store connection experienced an error.';
            notifyListeners();
          },
        );
      } else {
        _errorMessage =
            'Unable to reach the store. Please check your connection.';
      }
    } catch (error, stackTrace) {
      debugPrint('Storefront init failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _errorMessage = 'Failed to initialize the in-app purchase store.';
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> refreshProducts() async {
    if (!_isAvailable) {
      return;
    }
    await _queryProducts();
  }

  Future<void> buyProduct(ProductDetails product) async {
    if (!_isAvailable) {
      _errorMessage = 'Store is not available right now.';
      notifyListeners();
      return;
    }
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final catalogEntry = ProductCatalog.findById(product.id);
      if (catalogEntry == null) {
        _errorMessage = 'This product is currently unavailable.';
        _loading = false;
        notifyListeners();
        return;
      }
      final purchaseParam = PurchaseParam(productDetails: product);
      if (catalogEntry.kind == MonetizationProductKind.coinBundle) {
        await _inAppPurchase.buyConsumable(
          purchaseParam: purchaseParam,
          autoConsume: true,
        );
      } else {
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      }
    } catch (error, stackTrace) {
      debugPrint('Purchase request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _errorMessage = 'Purchase failed. Please try again in a moment.';
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      return;
    }
    _restoreInProgress = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _inAppPurchase.restorePurchases();
    } catch (error, stackTrace) {
      debugPrint('Restore failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _errorMessage = 'We could not restore your purchases.';
      _restoreInProgress = false;
      notifyListeners();
    }
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _loading = true;
          notifyListeners();
          break;
        case PurchaseStatus.canceled:
          _loading = false;
          _restoreInProgress = false;
          notifyListeners();
          break;
        case PurchaseStatus.error:
          _loading = false;
          _restoreInProgress = false;
          _errorMessage = 'The transaction did not complete. Please retry.';
          notifyListeners();
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _deliverProduct(purchase);
          break;
      }
      if (purchase.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  Future<void> _queryProducts() async {
    _loading = true;
    notifyListeners();
    try {
      final response = await _inAppPurchase.queryProductDetails(
        ProductCatalog.productIds,
      );
      if (response.error != null) {
        _errorMessage = response.error!.message;
      }
      final Map<String, ProductDetails> fetched = <String, ProductDetails>{};
      for (final product in response.productDetails) {
        fetched[product.id] = product;
      }
      _products = fetched;
    } catch (error, stackTrace) {
      debugPrint('Product query failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _errorMessage = 'Unable to load products from the store.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _deliverProduct(PurchaseDetails purchase) async {
    final catalogEntry = ProductCatalog.findById(purchase.productID);
    if (catalogEntry == null) {
      debugPrint('Unknown product id: ${purchase.productID}');
      _loading = false;
      _restoreInProgress = false;
      notifyListeners();
      return;
    }
    try {
      switch (catalogEntry.kind) {
        case MonetizationProductKind.coinBundle:
          final reward = catalogEntry.coinReward ?? 0;
          await _wallet.addCoins(reward, source: 'iap');
          await _analytics.logCoinsCollected(
            amount: reward,
            totalCoins: _wallet.totalCoins,
            source: 'iap',
          );
          break;
        case MonetizationProductKind.removeAds:
          await _wallet.grantRemoveAds();
          break;
        case MonetizationProductKind.coinMultiplier:
          final multiplier = catalogEntry.coinMultiplier ?? 1.0;
          await _wallet.grantCoinMultiplier(
            multiplier: multiplier,
            duration: catalogEntry.multiplierDuration,
          );
          break;
      }
      _loading = false;
      _restoreInProgress = false;
      _errorMessage = null;
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('Failed to grant entitlement: $error');
      debugPrintStack(stackTrace: stackTrace);
      _errorMessage =
          'Purchase completed, but the reward could not be granted.';
      _loading = false;
      _restoreInProgress = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
