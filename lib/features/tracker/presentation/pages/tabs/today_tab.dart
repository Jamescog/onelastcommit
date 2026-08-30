import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../core/util/utc_date.dart';
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
          // Signing back in is already under way; say so rather than
          // rendering a blank screen for the frame it takes.
          TrackerUnauthorized() => const EmptyStateView(
            icon: Icons.lock_outline,
            title: 'Your GitHub sign-in expired',
            message: 'Taking you back to sign in.',
            tone: AppTone.warning,
          ),
        };
      },
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.state});

  final TrackerLoaded state;

  static bool _busy(TrackerState s) => s is TrackerLoaded && s.isSyncing;

  @override
  Widget build(BuildContext context) {
    final streak = state.streak;
    // Filtered against the UTC day GitHub is counting, not the local one. At
    // UTC+13 a 09:00 commit belongs to yesterday's contribution day, and
    // listing it under a header that says "nothing counted yet" makes the
    // screen contradict itself — PLAN.md section 2's trap, on one card.
    final today = state.activity
        .where((a) => utcDateLabel(a.occurredAt) == streak.todayDate)
        .toList();

    return RefreshIndicator(
      // Awaited to the point the sync settles: returning as soon as the event
      // was dispatched made the spinner vanish instantly whether or not
      // anything had been fetched.
      onRefresh: () async {
        final bloc = context.read<TrackerBloc>()..add(const SyncTracker());
        await bloc.stream.firstWhere((s) => s is! TrackerLoading && !_busy(s));
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (streak.isUncertain) ...[
            StalenessBanner(
              isError: streak.freshness == DataFreshness.error,
              checkedAt: streak.checkedAt,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _StatusCard(streak: streak),
          const SizedBox(height: AppSpacing.lg),
          _QuickStats(streak: streak),
          const SizedBox(height: AppSpacing.xxl),
          SectionHeader(
            title: "Today's activity",
            subtitle: today.isEmpty
                ? 'The UTC day GitHub is counting'
                : '${today.length} ${today.length == 1 ? "entry" : "entries"} '
                      '· the UTC day GitHub is counting',
          ),
          const SizedBox(height: AppSpacing.md),
          if (today.isEmpty)
            _NothingYet(safe: streak.isSafeToday)
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

    // Three answers, not two. A streak of zero means one of two entirely
    // different things — you just lost a run, or you have not started one —
    // and rendering both as "0 day streak" tells someone who just broke
    // twenty-three days exactly what it tells a fresh install.
    final broken = !safe && streak.current == 0 && streak.previousStreak > 0;
    final brandNew =
        !safe && streak.current == 0 && streak.lastContributionDate == null;

    final headline = switch (true) {
      _ when safe => 'Safe today',
      _ when broken =>
        streak.previousStreak == 1
            ? 'Your streak ended'
            : 'Your ${streak.previousStreak}-day streak ended',
      _ when brandNew => 'No streak yet',
      _ => 'Nothing counted yet',
    };

    // Uncertainty is on the headline too, not only in the banner above it. A
    // confident green "Safe today" under a warning that we could not check is
    // the app arguing with itself.
    final hedged = streak.isUncertain
        ? (safe ? 'Safe as of the last check' : headline)
        : headline;

    final tone = safe ? AppTone.success : AppTone.danger;
    final fg = safe ? t.success : t.danger;

    return AppCard(
      tone: tone,
      accentEdge: true,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                safe ? Icons.check_circle_outline : Icons.error_outline,
                color: fg,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  hedged,
                  style: text.titleMedium?.copyWith(color: fg),
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
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    streak.current == 1 ? 'day' : 'days',
                    style: text.bodyMedium?.copyWith(color: t.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          if (broken || brandNew) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              broken
                  ? 'Day one starts with anything you push today.'
                  : 'Your first day starts with anything you push today.',
              style: text.bodySmall?.copyWith(color: t.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          // A countdown rather than a wall-clock time: the deadline is UTC
          // midnight, which is not midnight anywhere most people live.
          CountdownText(
            deadlineUtc: streak.deadlineUtc,
            safe: safe,
            onRollover: () =>
                context.read<TrackerBloc>().add(const SyncTracker()),
          ),
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

class _NothingYet extends StatelessWidget {
  const _NothingYet({required this.safe});

  /// Today already counted, but nothing shows in the feed.
  ///
  /// That combination is normal rather than contradictory — private repos
  /// never reach the events feed — so it needs its own wording. "Safe today"
  /// above "No activity recorded" reads as a bug.
  final bool safe;

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
            safe ? 'Counted, but nothing to show' : 'Nothing counted yet today',
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            safe
                ? 'Today counted on GitHub. Work in private repositories '
                      'never reaches the public activity feed, so there is '
                      'nothing to list here.'
                : 'Pushing to a default branch, opening an issue, or '
                      'reviewing a pull request all count.',
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
