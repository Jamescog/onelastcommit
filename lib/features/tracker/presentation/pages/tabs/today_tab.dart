import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../bloc/tracker_bloc.dart';
import '../../widgets/activity_row.dart';
import '../../widgets/countdown_text.dart';

/// The screen the app exists for: is the streak safe, and how long is left.
class TodayTab extends StatelessWidget {
  const TodayTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrackerBloc, TrackerState>(
      builder: (context, state) {
        return switch (state) {
          TrackerInitial() || TrackerLoading() => const _TodaySkeleton(),
          TrackerEmpty() => _Empty(
            onSync: () => context.read<TrackerBloc>().add(const SyncTracker()),
          ),
          TrackerFailure(:final message) => ErrorStateView(
            title: message,
            message:
                'Nothing is cached yet, so we cannot tell you where '
                'your streak stands.',
            onRetry: () => context.read<TrackerBloc>().add(const SyncTracker()),
          ),
          TrackerLoaded() => _Loaded(state: state),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.state});

  final TrackerLoaded state;

  @override
  Widget build(BuildContext context) {
    final streak = state.streak;
    final today = state.activity.where((a) => _isToday(a.occurredAt)).toList();

    return RefreshIndicator(
      onRefresh: () async =>
          context.read<TrackerBloc>().add(const SyncTracker()),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (streak.isUncertain) ...[
            _StalenessBanner(freshness: streak.freshness),
            const SizedBox(height: AppSpacing.md),
          ],
          _StatusCard(streak: streak),
          const SizedBox(height: AppSpacing.lg),
          _QuickStats(streak: streak),
          const SizedBox(height: AppSpacing.xxl),
          SectionHeader(
            title: "Today's activity",
            subtitle: today.isEmpty
                ? null
                : '${today.length} ${today.length == 1 ? "entry" : "entries"}',
          ),
          const SizedBox(height: AppSpacing.md),
          if (today.isEmpty)
            _NothingYet(atRisk: streak.atRisk)
          else
            ...today.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ActivityRow(activity: a),
              ),
            ),
          const SizedBox(height: AppSpacing.massive),
        ],
      ),
    );
  }

  static bool _isToday(DateTime at) {
    final now = DateTime.now();
    final local = at.toLocal();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }
}

/// The one card that answers the question. Tone carries the answer as much as
/// the words do, so the state reads before anything is parsed.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.streak});

  final StreakStatus streak;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final safe = streak.isSafeToday;

    return AppCard(
      tone: safe ? AppTone.success : AppTone.danger,
      accentEdge: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                safe ? Icons.check_circle_outline : Icons.error_outline,
                color: safe ? t.success : t.danger,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                safe ? 'Safe today' : 'Nothing counted yet',
                style: text.titleMedium?.copyWith(
                  color: safe ? t.success : t.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${streak.current}',
                style: text.displayLarge?.copyWith(color: t.textPrimary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  streak.current == 1 ? 'day streak' : 'day streak',
                  style: text.bodyMedium?.copyWith(color: t.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // A countdown rather than a wall-clock time: the deadline is UTC
          // midnight, which is not midnight anywhere most people live.
          CountdownText(deadlineUtc: streak.deadlineUtc, safe: safe),
        ],
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.streak});

  final StreakStatus streak;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: StatTileRow(
        tiles: [
          StatTile(
            value: '${streak.longest}',
            label: 'Longest',
            emphasis: StatEmphasis.compact,
          ),
          StatTile(
            value: '${streak.weekTotal}',
            label: 'This week',
            emphasis: StatEmphasis.compact,
          ),
          StatTile(
            value: '${streak.monthTotal}',
            label: 'This month',
            emphasis: StatEmphasis.compact,
          ),
        ],
      ),
    );
  }
}

/// Shown when the mirror cannot be vouched for.
///
/// It hedges rather than hides. Staying silent risks telling someone their
/// streak is safe when it may not be, and that is the failure this app cannot
/// afford. See PLAN.md section 1.
class _StalenessBanner extends StatelessWidget {
  const _StalenessBanner({required this.freshness});

  final DataFreshness freshness;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isError = freshness == DataFreshness.error;

    return AppCard(
      tone: AppTone.warning,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 16, color: t.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              isError
                  ? "Can't reach GitHub. This may have changed."
                  : "Showing what we last knew. Couldn't check just now.",
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: t.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _NothingYet extends StatelessWidget {
  const _NothingYet({required this.atRisk});

  final bool atRisk;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          Icon(
            Icons.commit_outlined,
            size: 28,
            color: context.tokens.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            atRisk ? 'Nothing counted yet today' : 'No activity recorded',
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Pushing to a default branch, opening an issue, or reviewing a '
            'pull request all count.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onSync});

  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.download_outlined,
      title: 'No history yet',
      message:
          'Pull your contribution history to see where your streak '
          'stands.',
      actionLabel: 'Fetch now',
      onAction: onSync,
      tone: AppTone.info,
    );
  }
}

class _TodaySkeleton extends StatelessWidget {
  const _TodaySkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        SkeletonCard(lines: 2),
        SizedBox(height: AppSpacing.lg),
        SkeletonCard(lines: 1),
        SizedBox(height: AppSpacing.xxl),
        SkeletonCard(),
      ],
    );
  }
}
