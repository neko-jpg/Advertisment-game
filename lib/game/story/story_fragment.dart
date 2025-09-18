import 'package:flutter/foundation.dart';

import '../models/game_models.dart';

/// Unlock requirements for a story fragment.
class StoryUnlockCondition {
  const StoryUnlockCondition({
    this.minScore,
    this.minDuration,
    this.requireLineUsage = false,
    this.requireAccidentDeath = false,
  })  : assert(minScore == null || minScore >= 0),
        assert(minDuration == null || minDuration >= Duration.zero);

  final int? minScore;
  final Duration? minDuration;
  final bool requireLineUsage;
  final bool requireAccidentDeath;

  bool isSatisfiedBy(RunStats stats) {
    if (minScore != null && stats.score < minScore!) {
      return false;
    }
    if (minDuration != null && stats.duration < minDuration!) {
      return false;
    }
    if (requireLineUsage && !stats.usedLine) {
      return false;
    }
    if (requireAccidentDeath && !stats.accidentDeath) {
      return false;
    }
    return true;
  }
}

/// Narrative fragment unlocked through play.
@immutable
class StoryFragment {
  const StoryFragment({
    required this.id,
    required this.title,
    required this.body,
    required this.unlockCondition,
  });

  final String id;
  final String title;
  final String body;
  final StoryUnlockCondition unlockCondition;
}

/// Saved state for a fragment.
class StoryProgressEntry {
  StoryProgressEntry({
    required this.fragmentId,
    this.unlockedAt,
    this.viewed = false,
  });

  final String fragmentId;
  DateTime? unlockedAt;
  bool viewed;

  Map<String, dynamic> toJson() {
    return {
      'id': fragmentId,
      'unlockedAt': unlockedAt?.toIso8601String(),
      'viewed': viewed,
    };
  }

  static StoryProgressEntry fromJson(Map<String, dynamic> json) {
    return StoryProgressEntry(
      fragmentId: json['id'] as String,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.tryParse(json['unlockedAt'] as String)
          : null,
      viewed: json['viewed'] as bool? ?? false,
    );
  }
}

/// Default library of narrative fragments.
class StoryFragmentLibrary {
  StoryFragmentLibrary._();

  static final List<StoryFragment> fragments = List.unmodifiable(<StoryFragment>[
    StoryFragment(
      id: 'fragment_awaken',
      title: '断章1：走り出す理由',
      body:
          '靴紐を結ぶ指が震えている。都市のスカイラインが、夜明け前の群青色に滲んだ。'
          ' 「線を描け。進み続けろ」——遠くの無線がそう囁く。',
      unlockCondition: StoryUnlockCondition(
        minDuration: const Duration(seconds: 15),
      ),
    ),
    StoryFragment(
      id: 'fragment_frequency',
      title: '断章2：ハミングの発信源',
      body:
          '倒れたホッパーの奥で、建材の隙間から揺れる光。そこには古い端末があり、'
          '同じ周波数で延々と送信を続けていた。「誰かが導いている？」',
      unlockCondition: StoryUnlockCondition(
        minScore: 450,
        requireLineUsage: true,
      ),
    ),
    StoryFragment(
      id: 'fragment_memory',
      title: '断章3：失われた街路図',
      body:
          '霧の向こう、描いた線が空へ溶ける地点で、かつての街路図が投影された。'
          'あなたが辿った軌跡と重なり、未到達の場所が淡く光る。',
      unlockCondition: StoryUnlockCondition(
        minScore: 900,
        minDuration: const Duration(seconds: 45),
      ),
    ),
  ]);

  static StoryFragment? byId(String id) {
    for (final fragment in fragments) {
      if (fragment.id == id) {
        return fragment;
      }
    }
    return null;
  }
}
