import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/kpi/session_metrics_tracker.dart';
import '../../../game/models/game_models.dart';
import '../../../game/state/meta_state.dart';

Future<void> showMetaProgressSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return const _MetaProgressSheet();
    },
  );
}

class _MetaProgressSheet extends StatelessWidget {
  const _MetaProgressSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      minChildSize: 0.45,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 24,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: _MetaContent(scrollController: controller),
            ),
          ),
        );
      },
    );
  }
}

class _MetaContent extends StatelessWidget {
  const _MetaContent({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Consumer2<SessionMetricsTracker, MetaProvider>(
      builder: (context, tracker, meta, _) {
        final KpiSnapshot snapshot = tracker.snapshot;
        final missions = meta.dailyMissions;
        final loginState = meta.loginRewardState;
        final canClaimLogin = meta.canClaimLoginBonus;

        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Text(
                    'Live KPI & Meta Progress',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Based on the targets in requirement 0, this dashboard tracks how your recent runs contribute to retention, engagement and monetization.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 20),
                  _KpiGrid(snapshot: snapshot),
                  const SizedBox(height: 28),
                  _LoginRewardCard(
                    state: loginState,
                    canClaim: canClaimLogin,
                    onClaim: canClaimLogin
                        ? () async {
                            final reward = await meta.claimLoginBonus();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('ログインボーナスで $reward コインを獲得！'),
                              ),
                            );
                          }
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Daily Missions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            if (missions.isEmpty)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '今日のミッションは準備中です。ランをプレイすると新しい目標が表示されます。',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final mission = missions[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MissionTile(
                        mission: mission,
                        onClaim: mission.completed && !mission.claimed
                            ? () async {
                                final reward = await meta.claimMissionReward(
                                  mission.id,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${mission.displayTitle} の報酬として $reward コインを獲得！',
                                    ),
                                  ),
                                );
                              }
                            : null,
                      ),
                    );
                  },
                  childCount: missions.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        );
      },
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.snapshot});

  final KpiSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final tiles = <_KpiTileData>[
      _KpiTileData(
        title: 'D1 Retention',
        value: snapshot.retentionD1,
        target: 0.35,
        description: 'Target ≥ 35%',
      ),
      _KpiTileData(
        title: 'D7 Retention',
        value: snapshot.retentionD7,
        target: 0.15,
        description: 'Target ≥ 15%',
      ),
      _KpiTileData(
        title: 'D30 Retention',
        value: snapshot.retentionD30,
        target: 0.05,
        description: 'Target ≥ 5%',
      ),
      _KpiTileData(
        title: 'Avg Session Length',
        value: snapshot.completedSessions > 0
            ? snapshot.averageSessionMinutes / 10
            : null,
        target: 0.6,
        formatOverride: snapshot.completedSessions > 0
            ? '${snapshot.averageSessionMinutes.toStringAsFixed(1)}m'
            : '--',
        description: 'Target ≥ 6 min',
      ),
      _KpiTileData(
        title: 'Sessions / Day',
        value: snapshot.sessionsPerDay > 0
            ? (snapshot.sessionsPerDay / 5).clamp(0.0, 1.0)
            : null,
        target: 0.6,
        formatOverride:
            snapshot.sessionsPerDay > 0 ? snapshot.sessionsPerDay.toStringAsFixed(1) : '--',
        description: 'Target ≥ 3/day',
      ),
      _KpiTileData(
        title: 'Rewarded View Rate',
        value: snapshot.rewardedViewRate,
        target: 0.35,
        description: 'Target ≥ 35%',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.35,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemBuilder: (context, index) => _KpiTile(data: tiles[index]),
    );
  }
}

class _KpiTileData {
  const _KpiTileData({
    required this.title,
    required this.target,
    required this.description,
    this.value,
    this.formatOverride,
  });

  final String title;
  final double target;
  final String description;
  final double? value;
  final String? formatOverride;
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.data});

  final _KpiTileData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayValue = data.formatOverride ??
        (data.value != null ? '${(data.value! * 100).toStringAsFixed(0)}%' : '--');
    final progress = data.value ?? 0;
    final meetsTarget = data.value != null && progress >= data.target;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: meetsTarget ? Colors.greenAccent.withOpacity(0.4) : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white70,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            displayValue,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.white12,
            color: meetsTarget ? Colors.greenAccent : Colors.blueAccent,
          ),
          const SizedBox(height: 8),
          Text(
            data.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginRewardCard extends StatelessWidget {
  const _LoginRewardCard({
    required this.state,
    required this.canClaim,
    this.onClaim,
  });

  final LoginRewardState? state;
  final bool canClaim;
  final Future<void> Function()? onClaim;

  @override
  Widget build(BuildContext context) {
    if (state == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          'ログインデータを同期しています…',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white70),
        ),
      );
    }
    final theme = Theme.of(context);
    final streak = state!.streak;
    final nextClaim = state!.nextClaim;
    final timeUntilNext = nextClaim.difference(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Login streak ${streak}d',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  canClaim
                      ? 'ログインボーナスを受け取れます'
                      : '次のボーナスまで ${_formatDuration(timeUntilNext)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onClaim,
            style: ElevatedButton.styleFrom(
              backgroundColor: canClaim ? Colors.amberAccent : Colors.white24,
              foregroundColor: canClaim ? Colors.black87 : Colors.white70,
            ),
            child: Text(canClaim ? 'Claim' : '待機中'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      return '準備完了';
    }
    if (duration.inHours >= 1) {
      return '${duration.inHours}h';
    }
    if (duration.inMinutes >= 1) {
      return '${duration.inMinutes}m';
    }
    return '${duration.inSeconds}s';
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({
    required this.mission,
    this.onClaim,
  });

  final DailyMission mission;
  final Future<void> Function()? onClaim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = mission.target == 0
        ? 0.0
        : (mission.progress / mission.target).clamp(0.0, 1.0);
    final isClaimable = mission.completed && !mission.claimed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isClaimable ? Colors.greenAccent.withOpacity(0.4) : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _missionIcon(mission.type),
                color: isClaimable ? Colors.greenAccent : Colors.white70,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _missionTitle(mission),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '+${mission.reward} coins',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.amberAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _missionDescription(mission),
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.white12,
            color: isClaimable ? Colors.greenAccent : Colors.blueAccent,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${mission.progress}/${mission.target}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white54,
                ),
              ),
              if (onClaim != null)
                ElevatedButton(
                  onPressed: onClaim,
                  child: const Text('Claim'),
                )
              else if (mission.claimed)
                Text(
                  'Claimed',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.greenAccent,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _missionIcon(MissionType type) {
    switch (type) {
      case MissionType.collectCoins:
        return Icons.monetization_on_outlined;
      case MissionType.surviveTime:
        return Icons.timer_outlined;
      case MissionType.drawTime:
        return Icons.brush_outlined;
      case MissionType.jumpCount:
        return Icons.flight_takeoff;
    }
  }

  String _missionTitle(DailyMission mission) {
    switch (mission.type) {
      case MissionType.collectCoins:
        return 'Coin Hunter';
      case MissionType.surviveTime:
        return 'Endurance Runner';
      case MissionType.drawTime:
        return 'Artist';
      case MissionType.jumpCount:
        return 'Jump Master';
    }
  }

  String _missionDescription(DailyMission mission) {
    switch (mission.type) {
      case MissionType.collectCoins:
        return 'Collect ${mission.target} coins';
      case MissionType.surviveTime:
        return 'Survive for ${mission.target} seconds';
      case MissionType.drawTime:
        return 'Draw lines for ${mission.target} seconds';
      case MissionType.jumpCount:
        return 'Perform ${mission.target} jumps';
    }
  }
}
