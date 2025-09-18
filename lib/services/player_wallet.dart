import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Maintains the player-owned premium entitlements and soft currency balance.
class PlayerWallet extends ChangeNotifier {
  PlayerWallet();

  static const String _coinsKey = 'qdd_total_coins';
  static const String _removeAdsKey = 'wallet_remove_ads';
  static const String _coinMultiplierKey = 'wallet_coin_multiplier';
  static const String _coinMultiplierExpiryKey =
      'wallet_coin_multiplier_expiry';

  final Completer<void> _readyCompleter = Completer<void>();

  SharedPreferences? _prefs;
  bool _isInitializing = false;
  int _coins = 0;
  bool _removeAds = false;
  double _coinMultiplier = 1.0;
  DateTime? _coinMultiplierExpiry;

  bool get isReady => _readyCompleter.isCompleted;

  Future<void> initialize() async {
    if (_readyCompleter.isCompleted || _isInitializing) {
      return _readyCompleter.future;
    }
    _isInitializing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      _coins = prefs.getInt(_coinsKey) ?? 0;
      _removeAds = prefs.getBool(_removeAdsKey) ?? false;
      _coinMultiplier = prefs.getDouble(_coinMultiplierKey) ?? 1.0;
      final expiryIso = prefs.getString(_coinMultiplierExpiryKey);
      if (expiryIso != null && expiryIso.isNotEmpty) {
        _coinMultiplierExpiry = DateTime.tryParse(expiryIso);
      }
      _refreshMultiplierState();
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('PlayerWallet initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
      notifyListeners();
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> ensureReady() async {
    if (!_readyCompleter.isCompleted) {
      await initialize();
      await _readyCompleter.future;
    }
  }

  int get totalCoins => _coins;

  bool get adsRemoved => _removeAds;

  double get coinMultiplier {
    _refreshMultiplierState();
    return _coinMultiplier;
  }

  Duration? get coinMultiplierRemaining {
    if (_coinMultiplierExpiry == null) {
      return null;
    }
    final remaining = _coinMultiplierExpiry!.difference(DateTime.now());
    if (remaining.isNegative) {
      return null;
    }
    return remaining;
  }

  Future<void> addCoins(int amount, {String source = 'store'}) async {
    if (amount <= 0) {
      return;
    }
    _coins += amount;
    await _persistCoins();
    notifyListeners();
  }

  /// Registers coins earned from gameplay applying the active multiplier.
  int registerRunCoins(int baseAmount) {
    if (baseAmount <= 0) {
      return 0;
    }
    final multiplier = coinMultiplier;
    final rewarded = (baseAmount * multiplier).round();
    if (rewarded <= 0) {
      return 0;
    }
    _coins += rewarded;
    unawaited(_persistCoins());
    notifyListeners();
    return rewarded;
  }

  Future<bool> spendCoins(int amount, {String reason = 'purchase'}) async {
    if (amount <= 0) {
      return true;
    }
    if (_coins < amount) {
      return false;
    }
    _coins -= amount;
    await _persistCoins();
    notifyListeners();
    return true;
  }

  Future<void> grantRemoveAds() async {
    if (_removeAds) {
      return;
    }
    _removeAds = true;
    await _prefs?.setBool(_removeAdsKey, true);
    notifyListeners();
  }

  Future<void> grantCoinMultiplier({
    required double multiplier,
    Duration? duration,
  }) async {
    if (multiplier <= 1.0) {
      _coinMultiplier = 1.0;
      _coinMultiplierExpiry = null;
    } else {
      _coinMultiplier = multiplier;
      _coinMultiplierExpiry =
          duration == null ? null : DateTime.now().add(duration);
    }
    await _prefs?.setDouble(_coinMultiplierKey, _coinMultiplier);
    if (_coinMultiplierExpiry != null) {
      await _prefs?.setString(
        _coinMultiplierExpiryKey,
        _coinMultiplierExpiry!.toIso8601String(),
      );
    } else {
      await _prefs?.remove(_coinMultiplierExpiryKey);
    }
    notifyListeners();
  }

  void _refreshMultiplierState() {
    if (_coinMultiplierExpiry == null) {
      return;
    }
    if (_coinMultiplierExpiry!.isBefore(DateTime.now())) {
      _coinMultiplier = 1.0;
      _coinMultiplierExpiry = null;
      unawaited(_prefs?.setDouble(_coinMultiplierKey, _coinMultiplier));
      unawaited(_prefs?.remove(_coinMultiplierExpiryKey));
      notifyListeners();
    }
  }

  Future<void> _persistCoins() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setInt(_coinsKey, _coins);
  }
}
