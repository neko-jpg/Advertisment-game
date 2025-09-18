import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/analytics/analytics_service.dart';
import '../components/player_skin.dart';
import '../models/game_models.dart';
import '../story/story_fragment.dart';

class MetaProvider with ChangeNotifier {
  MetaProvider({AnalyticsService? analytics}) : _analytics = analytics {
    _loadFromStorage();
  }

  final AnalyticsService? _analytics;

  static const _coinsKey = 'meta_total_coins';
  static const _ownedSkinsKey = 'meta_owned_skins';
  static const _selectedSkinKey = 'meta_selected_skin';
  static const _upgradeLevelsKey = 'meta_upgrade_levels';
  static const _settingsKey = 'meta_settings';
  static const _dailyMissionDataKey = 'meta_daily_missions';
  static const _dailyMissionDateKey = 'meta_daily_missions_date';
  static const _loginStreakKey = 'meta_login_streak';
  static const _lastLoginKey = 'meta_last_login';
  static const _nextLoginKey = 'meta_next_login';
  static const _gachaPityKey = 'meta_gacha_pity';
  static const _freeGachaKey = 'meta_free_gacha_available';
  static const _storyProgressKey = 'meta_story_progress';
  static const _leftHandPromptKey = 'meta_left_prompt_seen';

  final List<PlayerSkin> _skins = kDefaultSkins;
  final Set<String> _ownedSkinIds = {'default'};
  final Map<UpgradeType, int> _upgradeLevels = {
    UpgradeType.inkRegen: 0,
    UpgradeType.revive: 0,
    UpgradeType.coyote: 0,
  };
  List<UpgradeDefinition> _upgradeDefinitions = List.of(
    _defaultUpgradeDefinitions,
  );
  final List<StoryFragment> _storyFragments = StoryFragmentLibrary.fragments;
  final Map<String, StoryProgressEntry> _storyProgress = {};
  StoryFragment? _pendingStoryFragment;

  SharedPreferences? _prefs;
  bool _initialized = false;
  int _totalCoins = 0;
  String _selectedSkinId = 'default';

  bool _leftHandedMode = false;
  double _hapticStrength = 1.0;
  bool _colorBlindMode = false;
  bool _screenShake = true;
  bool _oneTapMode = false;

  List<DailyMission> _dailyMissions = [];
  DateTime? _missionDate;

  int _loginStreak = 0;
  DateTime? _lastLoginAt;
  DateTime? _nextLoginClaimAt;

  int _gachaPityCounter = 0;
  bool _freeGachaAvailable = true;
  bool _hasShownLeftHandPrompt = false;
  RunBoost? _queuedBoost;

  bool get isReady => _initialized;
  int get totalCoins => _totalCoins;
  List<PlayerSkin> get skins => _skins;
  List<DailyMission> get dailyMissions => List.unmodifiable(_dailyMissions);
  bool get hasDailyMissions => _dailyMissions.isNotEmpty;

  PlayerSkin get selectedSkin => _skins.firstWhere(
    (skin) => skin.id == _selectedSkinId,
    orElse: () => _skins.first,
  );

  bool isSkinOwned(String skinId) => _ownedSkinIds.contains(skinId);

  bool canAfford(PlayerSkin skin) => _totalCoins >= skin.cost;

  bool get leftHandedMode => _leftHandedMode;
  double get hapticStrength => _hapticStrength;
  bool get colorBlindMode => _colorBlindMode;
  bool get screenShakeEnabled => _screenShake;
  bool get oneTapMode => _oneTapMode;
  bool get hasShownLeftHandPrompt => _hasShownLeftHandPrompt;
  bool get canClaimFreeGacha => _freeGachaAvailable;
  List<StoryFragment> get storyFragments => List.unmodifiable(_storyFragments);
  List<StoryFragment> get unlockedStoryFragments => _storyFragments
      .where((fragment) => _storyProgress[fragment.id]?.unlockedAt != null)
      .toList(growable: false);
  StoryFragment? get pendingStoryFragment => _pendingStoryFragment;

  bool isStoryFragmentUnlocked(String fragmentId) =>
      _storyProgress[fragmentId]?.unlockedAt != null;

  bool isStoryFragmentViewed(String fragmentId) =>
      _storyProgress[fragmentId]?.viewed ?? false;

  UpgradeSnapshot get upgradeSnapshot => UpgradeSnapshot(
    inkRegenMultiplier: 1.0 + upgradeLevel(UpgradeType.inkRegen) * 0.12,
    maxRevives: 1 + upgradeLevel(UpgradeType.revive),
    coyoteBonusMs: upgradeLevel(UpgradeType.coyote) * 20.0,
  );

  List<UpgradeDefinition> get upgradeDefinitions =>
      List.unmodifiable(_upgradeDefinitions);

  MetaProvider applyUpgradeConfig(MetaRemoteConfig config) {
    final overrides = {
      for (final override in config.upgradeOverrides) override.type: override,
    };
    final updated = _defaultUpgradeDefinitions
        .map((definition) {
          final override = overrides[definition.type];
          if (override == null) {
            return definition;
          }
          return definition.copyWith(
            maxLevel: override.maxLevel ?? definition.maxLevel,
            baseCost: override.baseCost ?? definition.baseCost,
            costGrowth: override.costGrowth ?? definition.costGrowth,
          );
        })
        .toList(growable: false);

    if (_hasDifferentUpgradeDefinitions(updated)) {
      _upgradeDefinitions = updated;
      notifyListeners();
    }
    return this;
  }

  bool _hasDifferentUpgradeDefinitions(List<UpgradeDefinition> next) {
    if (_upgradeDefinitions.length != next.length) {
      return true;
    }
    for (var i = 0; i < next.length; i++) {
      final current = _upgradeDefinitions[i];
      final candidate = next[i];
      if (current.type != candidate.type ||
          current.maxLevel != candidate.maxLevel ||
          current.baseCost != candidate.baseCost ||
          current.costGrowth != candidate.costGrowth) {
        return true;
      }
    }
    return false;
  }

  int upgradeLevel(UpgradeType type) => _upgradeLevels[type] ?? 0;

  int upgradeCost(UpgradeType type) {
    final definition = _upgradeDefinitions.firstWhere(
      (element) => element.type == type,
    );
    final current = upgradeLevel(type);
    if (current >= definition.maxLevel) {
      return 0;
    }
    return definition.baseCost + definition.costGrowth * current;
  }

  bool get canClaimLoginBonus {
    if (_nextLoginClaimAt == null) return true;
    return DateTime.now().isAfter(_nextLoginClaimAt!);
  }

  LoginRewardState? get loginRewardState {
    if (_nextLoginClaimAt == null) {
      return LoginRewardState(streak: _loginStreak, nextClaim: DateTime.now());
    }
    return LoginRewardState(
      streak: _loginStreak,
      nextClaim: _nextLoginClaimAt!,
    );
  }

  Future<void> addCoins(int amount) async {
    if (amount <= 0) return;
    _totalCoins += amount;
    await _saveCoins();
    notifyListeners();
  }

  Future<bool> spendCoins(int amount) async {
    if (amount <= 0) return true;
    if (_totalCoins < amount) {
      return false;
    }
    _totalCoins -= amount;
    await _saveCoins();
    notifyListeners();
    return true;
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

  Future<bool> purchaseUpgrade(UpgradeType type) async {
    final current = upgradeLevel(type);
    final definition = _upgradeDefinitions.firstWhere(
      (element) => element.type == type,
    );
    if (current >= definition.maxLevel) {
      return false;
    }
    final cost = upgradeCost(type);
    if (cost > _totalCoins) {
      return false;
    }
    _totalCoins -= cost;
    _upgradeLevels[type] = current + 1;
    await Future.wait([_saveCoins(), _saveUpgradeLevels()]);
    notifyListeners();
    return true;
  }

  Future<int> claimMissionReward(String missionId) async {
    final mission = _dailyMissions.firstWhere(
      (mission) => mission.id == missionId,
      orElse: () => throw ArgumentError('Unknown mission: $missionId'),
    );
    if (!mission.completed || mission.claimed) {
      return 0;
    }
    mission.claimed = true;
    await addCoins(mission.reward);
    await _saveDailyMissions();
    return mission.reward;
  }

  Future<int> claimLoginBonus() async {
    if (!canClaimLoginBonus) {
      return 0;
    }
    final streak = _loginStreak + 1;
    int reward;
    if (streak % 7 == 0) {
      reward = 300;
    } else if (streak % 3 == 0) {
      reward = 160;
    } else {
      reward = 90;
    }
    _loginStreak = streak;
    _lastLoginAt = DateTime.now();
    _nextLoginClaimAt = DateTime.now().add(const Duration(hours: 20));
    await Future.wait([addCoins(reward), _saveLoginProgress()]);
    return reward;
  }

  Future<GachaResult> pullGacha({required bool viaAd}) async {
    final bool useFreeRoll = _freeGachaAvailable && !viaAd;
    if (!viaAd && !useFreeRoll) {
      const coinCost = 120;
      if (_totalCoins < coinCost) {
        throw StateError('Not enough coins to pull the gacha.');
      }
      _totalCoins -= coinCost;
      await _saveCoins();
    }

    final rng = Random(DateTime.now().millisecondsSinceEpoch);
    final unowned =
        _skins.where((skin) => !_ownedSkinIds.contains(skin.id)).toList();
    List<PlayerSkin> selectionPool = List.of(unowned);
    if (useFreeRoll) {
      selectionPool = selectionPool
          .where((skin) => skin.cost < 300)
          .toList(growable: false);
      if (selectionPool.isEmpty) {
        selectionPool = List.of(unowned);
      }
    }
    final rareCandidates = selectionPool
        .where((skin) => skin.cost >= 300)
        .toList(growable: false);

    bool guaranteed = false;
    PlayerSkin? rewardSkin;
    if (selectionPool.isNotEmpty) {
      if (!useFreeRoll && _gachaPityCounter >= 9 && rareCandidates.isNotEmpty) {
        rewardSkin = rareCandidates[rng.nextInt(rareCandidates.length)];
        guaranteed = true;
      } else {
        rewardSkin = selectionPool[rng.nextInt(selectionPool.length)];
      }
    }

    if (rewardSkin != null) {
      _ownedSkinIds.add(rewardSkin.id);
      await _saveOwnedSkins();
      _gachaPityCounter = rewardSkin.cost >= 300 ? 0 : _gachaPityCounter + 1;
      await _saveGachaState();
      if (useFreeRoll) {
        _freeGachaAvailable = false;
        await _saveFreeGachaState();
      }
      notifyListeners();
      return GachaResult(
        rewardId: 'skin_${rewardSkin.id}',
        displayName: rewardSkin.name,
        wasGuaranteed: guaranteed,
      );
    }

    // Fallback coin reward.
    final coinReward = 150;
    await addCoins(coinReward);
    _gachaPityCounter = (_gachaPityCounter + 1).clamp(0, 9);
    await _saveGachaState();
    if (useFreeRoll) {
      _freeGachaAvailable = false;
      await _saveFreeGachaState();
    }
    return const GachaResult(
      rewardId: 'coins_150',
      displayName: '150 Coins',
      wasGuaranteed: false,
    );
  }

  void updateSettings({
    bool? leftHanded,
    bool? oneTapMode,
    double? hapticStrength,
    bool? colorBlindMode,
    bool? screenShake,
  }) {
    if (leftHanded != null) {
      _leftHandedMode = leftHanded;
    }
    if (oneTapMode != null) {
      _oneTapMode = oneTapMode;
    }
    if (hapticStrength != null) {
      _hapticStrength = hapticStrength.clamp(0.0, 1.0);
    }
    if (colorBlindMode != null) {
      _colorBlindMode = colorBlindMode;
    }
    if (screenShake != null) {
      _screenShake = screenShake;
    }
    _saveSettings();
    notifyListeners();
  }

  Future<void> markLeftHandPromptSeen() async {
    if (_hasShownLeftHandPrompt) {
      return;
    }
    _hasShownLeftHandPrompt = true;
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setBool(_leftHandPromptKey, true);
    }
    notifyListeners();
  }

  void applyRunStats(RunStats stats) {
    if (_dailyMissions.isEmpty) {
      return;
    }
    for (final mission in _dailyMissions) {
      if (mission.completed) {
        continue;
      }
      switch (mission.type) {
        case MissionType.collectCoins:
          mission.progress += stats.coins;
          break;
        case MissionType.surviveTime:
          mission.progress += stats.duration.inSeconds;
          break;
        case MissionType.drawTime:
          mission.progress += (stats.drawTimeMs / 1000).round();
          break;
        case MissionType.jumpCount:
          mission.progress += stats.jumpsPerformed;
          break;
      }
      if (mission.progress >= mission.target) {
        final bool newlyCompleted = !mission.completed;
        mission.progress = mission.target;
        mission.completed = true;
        if (newlyCompleted) {
          _analytics?.logMissionComplete(
            missionId: mission.id,
            missionType: describeEnum(mission.type),
            reward: mission.reward,
          );
        }
      }
    }
    _saveDailyMissions();
    notifyListeners();
  }

  StoryFragment? unlockStoryFragmentForRun(RunStats stats) {
    StoryFragment? unlocked;
    for (final fragment in _storyFragments) {
      final progress = _storyProgress[fragment.id];
      if (progress?.unlockedAt != null) {
        continue;
      }
      if (!fragment.unlockCondition.isSatisfiedBy(stats)) {
        continue;
      }
      final entry = StoryProgressEntry(
        fragmentId: fragment.id,
        unlockedAt: DateTime.now(),
        viewed: false,
      );
      _storyProgress[fragment.id] = entry;
      unlocked = fragment;
      _pendingStoryFragment = fragment;
      break;
    }
    if (unlocked != null) {
      unawaited(_saveStoryProgress());
      notifyListeners();
    }
    return unlocked;
  }

  void markStoryFragmentViewed(String fragmentId) {
    final progress = _storyProgress[fragmentId];
    if (progress == null) {
      return;
    }
    var changed = false;
    if (!progress.viewed) {
      progress.viewed = true;
      changed = true;
    }
    if (_pendingStoryFragment?.id == fragmentId) {
      _pendingStoryFragment = null;
      changed = true;
    }
    if (changed) {
      unawaited(_saveStoryProgress());
      notifyListeners();
    }
  }

  Future<void> refreshDailyMissionsIfNeeded() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_missionDate == null ||
        _missionDate!.year != today.year ||
        _missionDate!.month != today.month ||
        _missionDate!.day != today.day) {
      _dailyMissions = _generateDailyMissions(today);
      _missionDate = today;
      await _saveDailyMissions();
      await _saveMissionDate();
      notifyListeners();
    }
  }

  void _resetToDefaults() {
    _prefs = null;
    _totalCoins = 0;
    _ownedSkinIds
      ..clear()
      ..add('default');
    _selectedSkinId = 'default';
    _upgradeLevels
      ..clear()
      ..addAll({
        UpgradeType.inkRegen: 0,
        UpgradeType.revive: 0,
        UpgradeType.coyote: 0,
      });
    _leftHandedMode = false;
    _hapticStrength = 1.0;
    _colorBlindMode = false;
    _screenShake = true;
    _oneTapMode = false;
    _dailyMissions = [];
    _missionDate = null;
    _loginStreak = 0;
    _lastLoginAt = null;
    _nextLoginClaimAt = null;
    _gachaPityCounter = 0;
    _freeGachaAvailable = true;
    _hasShownLeftHandPrompt = false;
    _queuedBoost = null;
    _storyProgress.clear();
    _pendingStoryFragment = null;
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      _totalCoins = prefs.getInt(_coinsKey) ?? 0;
      final owned = prefs.getStringList(_ownedSkinsKey);
      if (owned != null && owned.isNotEmpty) {
        _ownedSkinIds
          ..clear()
          ..addAll(owned);
      }
      _ownedSkinIds.add('default');

      final selected = prefs.getString(_selectedSkinKey);
      if (selected != null && _ownedSkinIds.contains(selected)) {
        _selectedSkinId = selected;
      }

      final upgradeRaw = prefs.getString(_upgradeLevelsKey);
      if (upgradeRaw != null) {
        final decoded = json.decode(upgradeRaw) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          final type = UpgradeType.values.firstWhere(
            (element) => describeEnum(element) == key,
            orElse: () => UpgradeType.inkRegen,
          );
          _upgradeLevels[type] = value as int;
        });
      }

      final settingsRaw = prefs.getString(_settingsKey);
      if (settingsRaw != null) {
        final decoded = json.decode(settingsRaw) as Map<String, dynamic>;
        _leftHandedMode = decoded['leftHanded'] as bool? ?? _leftHandedMode;
        _hapticStrength =
            (decoded['hapticStrength'] as num?)?.toDouble() ?? _hapticStrength;
        _colorBlindMode = decoded['colorBlind'] as bool? ?? _colorBlindMode;
        _screenShake = decoded['screenShake'] as bool? ?? _screenShake;
        _oneTapMode = decoded['oneTapMode'] as bool? ?? _oneTapMode;
      }

      final missionRaw = prefs.getString(_dailyMissionDataKey);
      if (missionRaw != null) {
        final list = json.decode(missionRaw) as List<dynamic>;
        _dailyMissions =
            list
                .map(
                  (item) => DailyMission.fromJson(item as Map<String, dynamic>),
                )
                .toList();
      }
      final missionDateRaw = prefs.getString(_dailyMissionDateKey);
      if (missionDateRaw != null) {
        _missionDate = DateTime.tryParse(missionDateRaw);
      }

      final loginStreak = prefs.getInt(_loginStreakKey);
      if (loginStreak != null) {
        _loginStreak = loginStreak;
      }
      final lastLogin = prefs.getString(_lastLoginKey);
      if (lastLogin != null) {
        _lastLoginAt = DateTime.tryParse(lastLogin);
      }
      final nextLogin = prefs.getString(_nextLoginKey);
      if (nextLogin != null) {
        _nextLoginClaimAt = DateTime.tryParse(nextLogin);
      }

      _gachaPityCounter = prefs.getInt(_gachaPityKey) ?? 0;
      _freeGachaAvailable = prefs.getBool(_freeGachaKey) ?? true;
      _hasShownLeftHandPrompt = prefs.getBool(_leftHandPromptKey) ?? false;
      final storyRaw = prefs.getString(_storyProgressKey);
      if (storyRaw != null) {
        try {
          final decoded = json.decode(storyRaw);
          if (decoded is List) {
            _storyProgress.clear();
            for (final entry in decoded) {
              if (entry is Map<String, dynamic>) {
                final progress = StoryProgressEntry.fromJson(entry);
                if (StoryFragmentLibrary.byId(progress.fragmentId) != null) {
                  _storyProgress[progress.fragmentId] = progress;
                }
              } else if (entry is Map) {
                final jsonEntry = entry.cast<String, dynamic>();
                final progress = StoryProgressEntry.fromJson(jsonEntry);
                if (StoryFragmentLibrary.byId(progress.fragmentId) != null) {
                  _storyProgress[progress.fragmentId] = progress;
                }
              }
            }
          }
        } catch (error, stackTrace) {
          debugPrint('Failed to parse story progress: $error');
          debugPrintStack(stackTrace: stackTrace);
          _storyProgress.clear();
        }
      }
    } catch (error, stackTrace) {
      debugPrint('MetaProvider storage load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _resetToDefaults();
    } finally {
      await refreshDailyMissionsIfNeeded();
      _initialized = true;
      notifyListeners();
    }
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

  Future<void> _saveUpgradeLevels() async {
    final prefs = _prefs;
    if (prefs != null) {
      final map = _upgradeLevels.map(
        (key, value) => MapEntry(describeEnum(key), value),
      );
      await prefs.setString(_upgradeLevelsKey, json.encode(map));
    }
  }

  Future<void> _saveSettings() async {
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setString(
        _settingsKey,
        json.encode({
          'leftHanded': _leftHandedMode,
          'hapticStrength': _hapticStrength,
          'colorBlind': _colorBlindMode,
          'screenShake': _screenShake,
        }),
      );
    }
  }

  Future<void> _saveDailyMissions() async {
    final prefs = _prefs;
    if (prefs != null) {
      final list = _dailyMissions.map((mission) => mission.toJson()).toList();
      await prefs.setString(_dailyMissionDataKey, json.encode(list));
    }
  }

  Future<void> _saveMissionDate() async {
    final prefs = _prefs;
    if (prefs != null && _missionDate != null) {
      await prefs.setString(
        _dailyMissionDateKey,
        _missionDate!.toIso8601String(),
      );
    }
  }

  Future<void> _saveLoginProgress() async {
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setInt(_loginStreakKey, _loginStreak);
      if (_lastLoginAt != null) {
        await prefs.setString(_lastLoginKey, _lastLoginAt!.toIso8601String());
      }
      if (_nextLoginClaimAt != null) {
        await prefs.setString(
          _nextLoginKey,
          _nextLoginClaimAt!.toIso8601String(),
        );
      }
    }
  }

  Future<void> _saveGachaState() async {
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setInt(_gachaPityKey, _gachaPityCounter);
    }
  }

  Future<void> _saveFreeGachaState() async {
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setBool(_freeGachaKey, _freeGachaAvailable);
    }
  }

  Future<void> _saveStoryProgress() async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    final list = _storyProgress.values
        .map((entry) => entry.toJson())
        .toList(growable: false);
    await prefs.setString(_storyProgressKey, json.encode(list));
  }

  void queueRunBoost(RunBoost boost) {
    _queuedBoost = boost;
    notifyListeners();
  }

  RunBoost? consumeQueuedBoost() {
    final boost = _queuedBoost;
    _queuedBoost = null;
    if (boost != null) {
      notifyListeners();
    }
    return boost;
  }

  List<DailyMission> _generateDailyMissions(DateTime today) {
    final seed = today.millisecondsSinceEpoch;
    final rng = Random(seed);
    return [
      DailyMission(
        id: 'coins_${today.toIso8601String()}',
        type: MissionType.collectCoins,
        target: 30 + rng.nextInt(25),
        reward: 80 + rng.nextInt(40),
      ),
      DailyMission(
        id: 'survive_${today.toIso8601String()}',
        type: MissionType.surviveTime,
        target: 35 + rng.nextInt(20),
        reward: 120,
      ),
      DailyMission(
        id: 'draw_${today.toIso8601String()}',
        type: MissionType.drawTime,
        target: 6 + rng.nextInt(6),
        reward: 100,
      ),
      DailyMission(
        id: 'jump_${today.toIso8601String()}',
        type: MissionType.jumpCount,
        target: 25 + rng.nextInt(20),
        reward: 90,
      ),
    ];
  }
}

final List<UpgradeDefinition> _defaultUpgradeDefinitions = [
  UpgradeDefinition(
    type: UpgradeType.inkRegen,
    maxLevel: 5,
    baseCost: 150,
    costGrowth: 120,
    displayName: 'Ink Injector',
    descriptionBuilder:
        (level) => '+${(level * 12).toStringAsFixed(0)}% ink regen rate',
  ),
  UpgradeDefinition(
    type: UpgradeType.revive,
    maxLevel: 3,
    baseCost: 300,
    costGrowth: 220,
    displayName: 'Extra Defib',
    descriptionBuilder: (level) => 'Revives per run: ${1 + level}',
  ),
  UpgradeDefinition(
    type: UpgradeType.coyote,
    maxLevel: 4,
    baseCost: 200,
    costGrowth: 160,
    displayName: 'Air Grace',
    descriptionBuilder: (level) => '+${level * 20}ms coyote window',
  ),
];
