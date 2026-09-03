import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
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
    final trend = TrendChart(
      values: [for (final d in recent) d.count],
      label: 'Daily contributions, last 90 days',
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (streak.isUncertain) ...[
          StalenessBanner(
            isError: streak.freshness == DataFreshness.error,
            checkedAt: streak.checkedAt,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        // A headline number is not a chart. Three of them beat a bar chart of
        // three bars.
        AppCard(
          child: StatTileRow(
            tiles: [
              StatTile(
                value: '${streak.current}',
                label: 'Current streak',
                tone: streak.current > 0 ? AppTone.success : AppTone.danger,
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
          child: ContributionHeatmap(
            days: days,
            todayDate: streak.todayDate,
            atRiskToday: streak.atRisk,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        // The chart draws nothing under two points, so the card around it has
        // to go too — a new user was getting an empty 32px box under a
        // heading that promised a chart.
        if (trend.hasSeries) ...[
          const SectionHeader(
            title: 'Daily contributions',
            subtitle: 'Last 90 days.',
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(child: trend),
          const SizedBox(height: AppSpacing.xxl),
        ],

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
