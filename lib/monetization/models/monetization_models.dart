import 'dart:convert';

/// Represents ad fatigue level for a user
enum AdFatigueLevel { none, low, medium, high, critical }

/// User's spending profile for monetization optimization
class SpendingProfile {
  const SpendingProfile({
    required this.userId,
    required this.totalSpent,
    required this.averageTransactionValue,
    required this.purchaseFrequency,
    required this.preferredPriceRange,
    required this.lastPurchaseDate,
    required this.conversionRate,
  });

  final String userId;
  final double totalSpent;
  final double averageTransactionValue;
  final double purchaseFrequency; // purchases per month
  final PriceRange preferredPriceRange;
  final DateTime? lastPurchaseDate;
  final double conversionRate; // 0-1

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'totalSpent': totalSpent,
      'averageTransactionValue': averageTransactionValue,
      'purchaseFrequency': purchaseFrequency,
      'preferredPriceRange': preferredPriceRange.name,
      'lastPurchaseDate': lastPurchaseDate?.toIso8601String(),
      'conversionRate': conversionRate,
    };
  }

  static SpendingProfile fromJson(Map<String, dynamic> json) {
    return SpendingProfile(
      userId: json['userId'] as String,
      totalSpent: (json['totalSpent'] as num).toDouble(),
      averageTransactionValue: (json['averageTransactionValue'] as num).toDouble(),
      purchaseFrequency: (json['purchaseFrequency'] as num).toDouble(),
      preferredPriceRange: PriceRange.values.firstWhere(
        (e) => e.name == json['preferredPriceRange'],
        orElse: () => PriceRange.low,
      ),
      lastPurchaseDate: json['lastPurchaseDate'] != null
          ? DateTime.parse(json['lastPurchaseDate'] as String)
          : null,
      conversionRate: (json['conversionRate'] as num).toDouble(),
    );
  }
}

enum PriceRange { low, medium, high, premium }

/// Ad interaction history for fatigue detection
class AdInteractionHistory {
  const AdInteractionHistory({
    required this.userId,
    required this.totalAdsViewed,
    required this.adsViewedToday,
    required this.lastAdViewTime,
    required this.averageViewDuration,
    required this.skipRate,
    required this.rewardedAdEngagement,
    required this.interstitialTolerance,
  });

  final String userId;
  final int totalAdsViewed;
  final int adsViewedToday;
  final DateTime? lastAdViewTime;
  final Duration averageViewDuration;
  final double skipRate; // 0-1
  final double rewardedAdEngagement; // 0-1
  final double interstitialTolerance; // 0-1

  AdFatigueLevel get fatigueLevel {
    if (adsViewedToday >= 20 || skipRate > 0.8) return AdFatigueLevel.critical;
    if (adsViewedToday >= 15 || skipRate > 0.6) return AdFatigueLevel.high;
    if (adsViewedToday >= 10 || skipRate > 0.4) return AdFatigueLevel.medium;
    if (adsViewedToday >= 5 || skipRate > 0.2) return AdFatigueLevel.low;
    return AdFatigueLevel.none;
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'totalAdsViewed': totalAdsViewed,
      'adsViewedToday': adsViewedToday,
      'lastAdViewTime': lastAdViewTime?.toIso8601String(),
      'averageViewDuration': averageViewDuration.inMilliseconds,
      'skipRate': skipRate,
      'rewardedAdEngagement': rewardedAdEngagement,
      'interstitialTolerance': interstitialTolerance,
    };
  }

  static AdInteractionHistory fromJson(Map<String, dynamic> json) {
    return AdInteractionHistory(
      userId: json['userId'] as String,
      totalAdsViewed: json['totalAdsViewed'] as int,
      adsViewedToday: json['adsViewedToday'] as int,
      lastAdViewTime: json['lastAdViewTime'] != null
          ? DateTime.parse(json['lastAdViewTime'] as String)
          : null,
      averageViewDuration: Duration(milliseconds: json['averageViewDuration'] as int),
      skipRate: (json['skipRate'] as num).toDouble(),
      rewardedAdEngagement: (json['rewardedAdEngagement'] as num).toDouble(),
      interstitialTolerance: (json['interstitialTolerance'] as num).toDouble(),
    );
  }
}

/// Game context for ad placement decisions
class GameContext {
  const GameContext({
    required this.currentScore,
    required this.sessionDuration,
    required this.gameState,
    required this.playerMood,
    required this.achievementJustUnlocked,
    required this.consecutiveFailures,
    required this.coinsEarned,
  });

  final int currentScore;
  final Duration sessionDuration;
  final GameState gameState;
  final PlayerMood playerMood;
  final bool achievementJustUnlocked;
  final int consecutiveFailures;
  final int coinsEarned;

  bool get isPositiveMoment => 
      playerMood == PlayerMood.excited || 
      achievementJustUnlocked || 
      currentScore > 0;

  bool get isNaturalBreakPoint =>
      gameState == GameState.gameOver ||
      gameState == GameState.levelComplete ||
      gameState == GameState.paused;

  Map<String, dynamic> toJson() {
    return {
      'currentScore': currentScore,
      'sessionDuration': sessionDuration.inMilliseconds,
      'gameState': gameState.name,
      'playerMood': playerMood.name,
      'achievementJustUnlocked': achievementJustUnlocked,
      'consecutiveFailures': consecutiveFailures,
      'coinsEarned': coinsEarned,
    };
  }

  static GameContext fromJson(Map<String, dynamic> json) {
    return GameContext(
      currentScore: json['currentScore'] as int,
      sessionDuration: Duration(milliseconds: json['sessionDuration'] as int),
      gameState: GameState.values.firstWhere(
        (e) => e.name == json['gameState'],
        orElse: () => GameState.playing,
      ),
      playerMood: PlayerMood.values.firstWhere(
        (e) => e.name == json['playerMood'],
        orElse: () => PlayerMood.neutral,
      ),
      achievementJustUnlocked: json['achievementJustUnlocked'] as bool,
      consecutiveFailures: json['consecutiveFailures'] as int,
      coinsEarned: json['coinsEarned'] as int,
    );
  }
}

enum GameState { playing, paused, gameOver, levelComplete, menu }
enum PlayerMood { frustrated, neutral, satisfied, excited }

/// In-app purchase offer
class IAPOffer {
  const IAPOffer({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.currency,
    required this.value,
    required this.discountPercentage,
    required this.urgency,
    required this.personalizedReason,
  });

  final String id;
  final String title;
  final String description;
  final double price;
  final String currency;
  final Map<String, int> value; // item_type -> quantity
  final double discountPercentage;
  final OfferUrgency urgency;
  final String personalizedReason;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'currency': currency,
      'value': value,
      'discountPercentage': discountPercentage,
      'urgency': urgency.name,
      'personalizedReason': personalizedReason,
    };
  }

  static IAPOffer fromJson(Map<String, dynamic> json) {
    return IAPOffer(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
      value: Map<String, int>.from(json['value'] as Map),
      discountPercentage: (json['discountPercentage'] as num).toDouble(),
      urgency: OfferUrgency.values.firstWhere(
        (e) => e.name == json['urgency'],
        orElse: () => OfferUrgency.none,
      ),
      personalizedReason: json['personalizedReason'] as String,
    );
  }
}

enum OfferUrgency { none, low, medium, high }

/// Subscription offer
class SubscriptionOffer {
  const SubscriptionOffer({
    required this.id,
    required this.title,
    required this.description,
    required this.monthlyPrice,
    required this.currency,
    required this.benefits,
    required this.trialDays,
    required this.discountPercentage,
    required this.personalizedPitch,
  });

  final String id;
  final String title;
  final String description;
  final double monthlyPrice;
  final String currency;
  final List<String> benefits;
  final int trialDays;
  final double discountPercentage;
  final String personalizedPitch;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'monthlyPrice': monthlyPrice,
      'currency': currency,
      'benefits': benefits,
      'trialDays': trialDays,
      'discountPercentage': discountPercentage,
      'personalizedPitch': personalizedPitch,
    };
  }

  static SubscriptionOffer fromJson(Map<String, dynamic> json) {
    return SubscriptionOffer(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      monthlyPrice: (json['monthlyPrice'] as num).toDouble(),
      currency: json['currency'] as String,
      benefits: List<String>.from(json['benefits'] as List),
      trialDays: json['trialDays'] as int,
      discountPercentage: (json['discountPercentage'] as num).toDouble(),
      personalizedPitch: json['personalizedPitch'] as String,
    );
  }
}

/// Monetization data for a user
class MonetizationData {
  const MonetizationData({
    required this.userId,
    required this.adInteractionHistory,
    required this.spendingProfile,
    required this.subscriptionStatus,
    required this.lifetimeValue,
    required this.lastOfferShown,
    required this.offerConversionRate,
  });

  final String userId;
  final AdInteractionHistory adInteractionHistory;
  final SpendingProfile spendingProfile;
  final SubscriptionStatus subscriptionStatus;
  final double lifetimeValue;
  final DateTime? lastOfferShown;
  final double offerConversionRate;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'adInteractionHistory': adInteractionHistory.toJson(),
      'spendingProfile': spendingProfile.toJson(),
      'subscriptionStatus': subscriptionStatus.toJson(),
      'lifetimeValue': lifetimeValue,
      'lastOfferShown': lastOfferShown?.toIso8601String(),
      'offerConversionRate': offerConversionRate,
    };
  }

  static MonetizationData fromJson(Map<String, dynamic> json) {
    return MonetizationData(
      userId: json['userId'] as String,
      adInteractionHistory: AdInteractionHistory.fromJson(
        json['adInteractionHistory'] as Map<String, dynamic>,
      ),
      spendingProfile: SpendingProfile.fromJson(
        json['spendingProfile'] as Map<String, dynamic>,
      ),
      subscriptionStatus: SubscriptionStatus.fromJson(
        json['subscriptionStatus'] as Map<String, dynamic>,
      ),
      lifetimeValue: (json['lifetimeValue'] as num).toDouble(),
      lastOfferShown: json['lastOfferShown'] != null
          ? DateTime.parse(json['lastOfferShown'] as String)
          : null,
      offerConversionRate: (json['offerConversionRate'] as num).toDouble(),
    );
  }
}

/// Subscription status
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.isActive,
    required this.tier,
    required this.startDate,
    required this.expiryDate,
    required this.autoRenew,
    required this.trialUsed,
  });

  final bool isActive;
  final String tier;
  final DateTime? startDate;
  final DateTime? expiryDate;
  final bool autoRenew;
  final bool trialUsed;

  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'tier': tier,
      'startDate': startDate?.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'autoRenew': autoRenew,
      'trialUsed': trialUsed,
    };
  }

  static SubscriptionStatus fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      isActive: json['isActive'] as bool,
      tier: json['tier'] as String,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'] as String)
          : null,
      autoRenew: json['autoRenew'] as bool,
      trialUsed: json['trialUsed'] as bool,
    );
  }
}