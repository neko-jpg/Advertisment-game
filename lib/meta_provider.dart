import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'player_skin.dart';

class MetaProvider with ChangeNotifier {
  MetaProvider() {
    _loadFromStorage();
  }

  static const _coinsKey = 'meta_total_coins';
  static const _ownedSkinsKey = 'meta_owned_skins';
  static const _selectedSkinKey = 'meta_selected_skin';

  final List<PlayerSkin> _skins = kDefaultSkins;
  final Set<String> _ownedSkinIds = {'default'};

  SharedPreferences? _prefs;
  bool _initialized = false;
  int _totalCoins = 0;
  String _selectedSkinId = 'default';

  bool get isReady => _initialized;
  int get totalCoins => _totalCoins;
  List<PlayerSkin> get skins => _skins;

  PlayerSkin get selectedSkin =>
      _skins.firstWhere((skin) => skin.id == _selectedSkinId,
          orElse: () => _skins.first);

  bool isSkinOwned(String skinId) => _ownedSkinIds.contains(skinId);

  bool canAfford(PlayerSkin skin) => _totalCoins >= skin.cost;

  Future<void> addCoins(int amount) async {
    if (amount <= 0) return;
    _totalCoins += amount;
    await _saveCoins();
    notifyListeners();
  }

  Future<bool> purchaseSkin(PlayerSkin skin) async {
    if (_ownedSkinIds.contains(skin.id)) {
      return true;
    }
    if (skin.cost > _totalCoins) {
      return false;
    }

    _totalCoins -= skin.cost;
    _ownedSkinIds.add(skin.id);
    await _saveOwnedSkins();
    await _saveCoins();
    notifyListeners();
    return true;
  }

  Future<void> selectSkin(PlayerSkin skin) async {
    if (!_ownedSkinIds.contains(skin.id)) {
      return;
    }
    _selectedSkinId = skin.id;
    await _saveSelectedSkin();
    notifyListeners();
  }

  Future<void> _loadFromStorage() async {
    _prefs = await SharedPreferences.getInstance();
    _totalCoins = _prefs?.getInt(_coinsKey) ?? 0;
    final owned = _prefs?.getStringList(_ownedSkinsKey);
    if (owned != null && owned.isNotEmpty) {
      _ownedSkinIds
        ..clear()
        ..addAll(owned);
    }
    _ownedSkinIds.add('default');

    final selected = _prefs?.getString(_selectedSkinKey);
    if (selected != null && _ownedSkinIds.contains(selected)) {
      _selectedSkinId = selected;
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> _saveCoins() async {
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setInt(_coinsKey, _totalCoins);
    }
  }

  Future<void> _saveOwnedSkins() async {
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setStringList(_ownedSkinsKey, _ownedSkinIds.toList());
    }
  }

  Future<void> _saveSelectedSkin() async {
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setString(_selectedSkinKey, _selectedSkinId);
    }
  }
}
