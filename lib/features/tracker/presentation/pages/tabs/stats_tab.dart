import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../bloc/tracker_bloc.dart';
import '../../widgets/contribution_heatmap.dart';
import '../../widgets/trend_chart.dart';

class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrackerBloc, TrackerState>(
      builder: (context, state) {
        if (state is TrackerLoaded) return _Loaded(state: state);
        if (state is TrackerFailure) {
          return ErrorStateView(
            title: 'Stats unavailable',
            message: state.message,
            onRetry: () => context.read<TrackerBloc>().add(const SyncTracker()),
          );
        }
        if (state is TrackerEmpty) {
          return const EmptyStateView(
            icon: Icons.insights_outlined,
            title: 'No stats yet',
            message: 'Fetch your history from the Today tab first.',
          );
        }
        return const _StatsSkeleton();
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
    final days = state.calendar;
    final recent = days.length > 90 ? days.sublist(days.length - 90) : days;
    final total = days.fold<int>(0, (s, d) => s + d.count);
    final active = days.where((d) => d.hasContributions).length;
    final uncounted = days.fold<int>(0, (s, d) => s + d.uncountedPushes);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // A headline number is not a chart. Three of them beat a bar chart of
        // three bars.
        AppCard(
          child: StatTileRow(
            tiles: [
              StatTile(
                value: '${streak.current}',
                label: 'Current streak',
                tone: streak.current > 0 ? AppTone.accent : AppTone.danger,
                emphasis: StatEmphasis.compact,
              ),
              StatTile(
                value: '${streak.longest}',
                label: 'Longest',
                emphasis: StatEmphasis.compact,
              ),
              StatTile(
                value: '$total',
                label: 'Contributions',
                emphasis: StatEmphasis.compact,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        const SectionHeader(
          title: 'Contribution graph',
          subtitle: 'The same days GitHub counts, in the same five steps.',
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: ContributionHeatmap(days: days, atRiskToday: streak.atRisk),
        ),
        const SizedBox(height: AppSpacing.xxl),

        const SectionHeader(
          title: 'Daily contributions',
          subtitle: 'Last 90 days.',
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(child: TrendChart(values: [for (final d in recent) d.count])),
        const SizedBox(height: AppSpacing.xxl),

        const SectionHeader(title: 'Consistency'),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: StatTileRow(
            tiles: [
              StatTile(
                value: days.isEmpty
                    ? '—'
                    : '${(active / days.length * 100).round()}%',
                label: 'Days active',
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
        ),

        if (uncounted > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          // The number no other GitHub client will show you.
          AppCard(
            tone: AppTone.warning,
            accentEdge: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$uncounted pushes never counted',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.tokens.warning,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Work on feature branches, in forks, or committed from an '
                  'unregistered email earns no square. Check the Repos tab '
                  'to see where.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.massive),
      ],
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        SkeletonCard(lines: 1),
        SizedBox(height: AppSpacing.xxl),
        SkeletonCard(lines: 4),
        SizedBox(height: AppSpacing.xxl),
        SkeletonCard(lines: 2),
      ],
    );
  }
}
