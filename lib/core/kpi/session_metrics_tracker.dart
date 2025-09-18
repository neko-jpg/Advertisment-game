import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../game/models/game_models.dart';

/// Tracks gameplay sessions to monitor progress against the KPI targets
/// defined in AGENTS.md (requirement 0 and 8).
class SessionMetricsTracker extends ChangeNotifier {
  SessionMetricsTracker({SharedPreferences? prefs}) : _prefs = prefs;

  static const String _storageKey = 'qdd_session_metrics_v1';
  static const int _maxStoredSessions = 120;

  final Map<String, SessionRecord> _openSessions = <String, SessionRecord>{};
  final List<SessionRecord> _history = <SessionRecord>[];

  SharedPreferences? _prefs;
  bool _initialized = false;
  bool _initializing = false;

  KpiSnapshot _snapshot = KpiSnapshot.empty();

  KpiSnapshot get snapshot => _snapshot;
  bool get isInitialized => _initialized;

  /// Loads previously stored session history from persistent storage.
  Future<void> initialize() async {
    if (_initialized || _initializing) {
      return;
    }
    _initializing = true;
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw) as List<dynamic>;
        for (final item in decoded) {
          final record = SessionRecord.fromJson(item as Map<String, dynamic>);
          _history.add(record);
          if (!record.completed) {
            _openSessions[record.sessionId] = record;
          }
        }
        _snapshot = _computeSnapshot();
      } catch (error, stackTrace) {
        debugPrint('SessionMetricsTracker: failed to restore state: $error');
        debugPrintStack(stackTrace: stackTrace);
        _history.clear();
        _openSessions.clear();
        _snapshot = KpiSnapshot.empty();
      }
    }
    _initialized = true;
    _initializing = false;
    notifyListeners();
  }

  /// Records the start of a new gameplay session.
  void recordGameStart({
    required String sessionId,
    required bool tutorialActive,
    required int revivesUnlocked,
    required double inkMultiplier,
    required bool missionsAvailable,
    required int totalCoins,
  }) {
    final record = SessionRecord(
      sessionId: sessionId,
      startedAt: DateTime.now(),
      tutorialActive: tutorialActive,
      revivesUnlocked: revivesUnlocked,
      inkMultiplier: inkMultiplier,
      missionsAvailable: missionsAvailable,
      totalCoinsAtStart: totalCoins,
    );
    _openSessions.remove(sessionId);
    _openSessions[sessionId] = record;
    _history.removeWhere((element) => element.sessionId == sessionId);
    _history.add(record);
    _trimHistory();
    _persist();
    // No notifyListeners call to avoid rebuilds before data changes.
  }

  /// Records the end of a gameplay session and updates KPI snapshot.
  KpiSnapshot recordGameEnd({
    required String sessionId,
    required RunStats stats,
    required int revivesUsed,
    required int missionsCompletedDelta,
    required int coinsGained,
  }) {
    final record = _openSessions.remove(sessionId) ??
        _history.lastWhere(
          (element) => element.sessionId == sessionId,
          orElse: () => SessionRecord(
            sessionId: sessionId,
            startedAt: DateTime.now(),
            tutorialActive: false,
            revivesUnlocked: 0,
            inkMultiplier: 1.0,
            missionsAvailable: false,
            totalCoinsAtStart: 0,
          ),
        );
    record
      ..endedAt = record.startedAt.add(stats.duration)
      ..coinsGained = coinsGained
      ..revivesUsed = revivesUsed
      ..missionsCompletedDelta = missionsCompletedDelta;
    if (!_history.contains(record)) {
      _history.add(record);
      _trimHistory();
    }
    _persist();
    _snapshot = _computeSnapshot();
    notifyListeners();
    return _snapshot;
  }

  /// Records a rewarded ad view for the active session.
  void recordRewardedView(String sessionId, {required bool completed}) {
    final record = _openSessions[sessionId] ??
        _history.lastWhere(
          (element) => element.sessionId == sessionId,
          orElse: () => SessionRecord(
            sessionId: sessionId,
            startedAt: DateTime.now(),
            tutorialActive: false,
            revivesUnlocked: 0,
            inkMultiplier: 1.0,
            missionsAvailable: false,
            totalCoinsAtStart: 0,
          ),
        );
    record.rewardedViewsStarted += 1;
    if (completed) {
      record.rewardedViewsCompleted += 1;
    }
    if (!_history.contains(record)) {
      _history.add(record);
      _trimHistory();
    }
    _persist();
    _snapshot = _computeSnapshot();
    notifyListeners();
  }

  void _trimHistory() {
    if (_history.length <= _maxStoredSessions) {
      return;
    }
    _history.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    while (_history.length > _maxStoredSessions) {
      final removed = _history.removeAt(0);
      _openSessions.remove(removed.sessionId);
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final encoded = json.encode(
        _history.map((e) => e.toJson()).toList(growable: false),
      );
      await prefs.setString(_storageKey, encoded);
      _prefs = prefs;
    } catch (error, stackTrace) {
      debugPrint('SessionMetricsTracker: failed to persist data: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  KpiSnapshot _computeSnapshot() {
    if (_history.isEmpty) {
      return KpiSnapshot.empty();
    }
    final List<SessionRecord> completed = _history
        .where((session) => session.completed)
        .toList(growable: false);
    if (completed.isEmpty) {
      return KpiSnapshot(
        totalSessions: _history.length,
        completedSessions: 0,
        averageSessionMinutes: 0,
        sessionsPerDay: 0,
        sessionsToday: 0,
        rewardedViewRate: 0,
        retentionD1: null,
        retentionD7: null,
        retentionD30: null,
      );
    }
    completed.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final nowDay = _truncateToDay(DateTime.now());

    double totalMinutes = 0;
    final Map<DateTime, int> sessionsByDay = <DateTime, int>{};
    int rewardedCompleted = 0;

    for (final session in completed) {
      totalMinutes += session.duration.inSeconds / 60;
      final day = _truncateToDay(session.startedAt);
      sessionsByDay[day] = (sessionsByDay[day] ?? 0) + 1;
      rewardedCompleted += session.rewardedViewsCompleted;
    }

    final List<int> recentDayCounts = <int>[];
    sessionsByDay.forEach((day, count) {
      final diff = nowDay.difference(day).inDays;
      if (diff >= 0 && diff <= 6) {
        recentDayCounts.add(count);
      }
    });
    final double sessionsPerDay = recentDayCounts.isNotEmpty
        ? recentDayCounts.reduce((value, element) => value + element) /
            recentDayCounts.length
        : sessionsByDay.values.reduce((value, element) => value + element) /
            sessionsByDay.length;

    final int sessionsToday = sessionsByDay[nowDay] ?? 0;

    final double rewardedViewRate =
        completed.isEmpty ? 0 : rewardedCompleted / completed.length;

    final retentionD1 = _retentionForDay(sessionsByDay, targetDay: 1);
    final retentionD7 = _retentionForDay(sessionsByDay, targetDay: 7);
    final retentionD30 = _retentionForDay(sessionsByDay, targetDay: 30);

    return KpiSnapshot(
      totalSessions: _history.length,
      completedSessions: completed.length,
      averageSessionMinutes: totalMinutes / completed.length,
      sessionsPerDay: sessionsPerDay,
      sessionsToday: sessionsToday,
      rewardedViewRate: rewardedViewRate,
      retentionD1: retentionD1,
      retentionD7: retentionD7,
      retentionD30: retentionD30,
    );
  }

  double? _retentionForDay(
    Map<DateTime, int> sessionsByDay, {
    required int targetDay,
  }) {
    if (sessionsByDay.isEmpty) {
      return null;
    }
    final firstDay = sessionsByDay.keys.reduce(
      (value, element) => value.isBefore(element) ? value : element,
    );
    final target = _truncateToDay(
      DateTime(firstDay.year, firstDay.month, firstDay.day + targetDay),
    );
    final nowDay = _truncateToDay(DateTime.now());
    final int daysSinceFirst = nowDay.difference(firstDay).inDays;
    if (daysSinceFirst < targetDay) {
      return null;
    }
    return sessionsByDay.containsKey(target) ? 1.0 : 0.0;
  }

  DateTime _truncateToDay(DateTime time) {
    return DateTime(time.year, time.month, time.day);
  }
}

/// Immutable snapshot of KPI progress derived from session history.
class KpiSnapshot {
  const KpiSnapshot({
    required this.totalSessions,
    required this.completedSessions,
    required this.averageSessionMinutes,
    required this.sessionsPerDay,
    required this.sessionsToday,
    required this.rewardedViewRate,
    required this.retentionD1,
    required this.retentionD7,
    required this.retentionD30,
  });

  const KpiSnapshot.empty()
      : totalSessions = 0,
        completedSessions = 0,
        averageSessionMinutes = 0,
        sessionsPerDay = 0,
        sessionsToday = 0,
        rewardedViewRate = 0,
        retentionD1 = null,
        retentionD7 = null,
        retentionD30 = null;

  final int totalSessions;
  final int completedSessions;
  final double averageSessionMinutes;
  final double sessionsPerDay;
  final int sessionsToday;
  final double rewardedViewRate;
  final double? retentionD1;
  final double? retentionD7;
  final double? retentionD30;

  bool get meetsD1Target => retentionD1 != null && retentionD1! >= 0.35;
  bool get meetsD7Target => retentionD7 != null && retentionD7! >= 0.15;
  bool get meetsD30Target => retentionD30 != null && retentionD30! >= 0.05;
  bool get meetsAverageSessionTarget => averageSessionMinutes >= 6.0;
  bool get meetsDailySessionsTarget => sessionsPerDay >= 3.0;
  bool get meetsRewardedRateTarget => rewardedViewRate >= 0.35;

  Map<String, Object?> toAnalyticsParameters() {
    return <String, Object?>{
      'total_sessions': totalSessions,
      'completed_sessions': completedSessions,
      'avg_session_minutes':
          double.parse(averageSessionMinutes.toStringAsFixed(2)),
      'sessions_per_day': double.parse(sessionsPerDay.toStringAsFixed(2)),
      'sessions_today': sessionsToday,
      'rewarded_view_rate':
          double.parse(rewardedViewRate.toStringAsFixed(3)),
      'retention_d1':
          retentionD1 != null ? double.parse(retentionD1!.toStringAsFixed(3)) : null,
      'retention_d7':
          retentionD7 != null ? double.parse(retentionD7!.toStringAsFixed(3)) : null,
      'retention_d30':
          retentionD30 != null ? double.parse(retentionD30!.toStringAsFixed(3)) : null,
    };
  }
}

/// Serialized record of a single gameplay session.
class SessionRecord {
  SessionRecord({
    required this.sessionId,
    required this.startedAt,
    required this.tutorialActive,
    required this.revivesUnlocked,
    required this.inkMultiplier,
    required this.missionsAvailable,
    required this.totalCoinsAtStart,
    DateTime? endedAt,
    this.revivesUsed = 0,
    this.missionsCompletedDelta = 0,
    this.coinsGained = 0,
    this.rewardedViewsStarted = 0,
    this.rewardedViewsCompleted = 0,
  }) : endedAt = endedAt;

  final String sessionId;
  final DateTime startedAt;
  DateTime? endedAt;
  final bool tutorialActive;
  final int revivesUnlocked;
  final double inkMultiplier;
  final bool missionsAvailable;
  final int totalCoinsAtStart;
  int revivesUsed;
  int missionsCompletedDelta;
  int coinsGained;
  int rewardedViewsStarted;
  int rewardedViewsCompleted;

  bool get completed => endedAt != null;

  Duration get duration =>
      completed ? endedAt!.difference(startedAt) : Duration.zero;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sessionId': sessionId,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'tutorialActive': tutorialActive,
      'revivesUnlocked': revivesUnlocked,
      'inkMultiplier': inkMultiplier,
      'missionsAvailable': missionsAvailable,
      'totalCoinsAtStart': totalCoinsAtStart,
      'revivesUsed': revivesUsed,
      'missionsCompletedDelta': missionsCompletedDelta,
      'coinsGained': coinsGained,
      'rewardedViewsStarted': rewardedViewsStarted,
      'rewardedViewsCompleted': rewardedViewsCompleted,
    };
  }

  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    return SessionRecord(
      sessionId: json['sessionId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] != null
          ? DateTime.tryParse(json['endedAt'] as String)
          : null,
      tutorialActive: json['tutorialActive'] as bool? ?? false,
      revivesUnlocked: json['revivesUnlocked'] as int? ?? 0,
      inkMultiplier: (json['inkMultiplier'] as num?)?.toDouble() ?? 1.0,
      missionsAvailable: json['missionsAvailable'] as bool? ?? false,
      totalCoinsAtStart: json['totalCoinsAtStart'] as int? ?? 0,
      revivesUsed: json['revivesUsed'] as int? ?? 0,
      missionsCompletedDelta: json['missionsCompletedDelta'] as int? ?? 0,
      coinsGained: json['coinsGained'] as int? ?? 0,
      rewardedViewsStarted: json['rewardedViewsStarted'] as int? ?? 0,
      rewardedViewsCompleted: json['rewardedViewsCompleted'] as int? ?? 0,
    );
  }
}
