import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/entities.dart';
import '../bloc/tracker_bloc.dart';
import '../widgets/histogram_chart.dart';
import '../widgets/trend_chart.dart';

/// What has happened since the app was installed.
///
/// Everything here runs on the OLC clock, not the GitHub clock. The Stats tab
/// shows the contribution graph, which anyone can see on github.com; this page
/// shows what only this app knows — when reminders fired, whether they worked,
/// and the rhythm underneath. See PLAN.md section 4.
class AnalysisPage extends StatelessWidget {
  const AnalysisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis')),
      body: BlocBuilder<TrackerBloc, TrackerState>(
        builder: (context, state) {
          final insights = state is TrackerLoaded ? state.insights : null;

          if (insights == null) {
            return const EmptyStateView(
              icon: Icons.query_stats_outlined,
              title: 'Nothing to analyse yet',
              message:
                  'This page fills in as the app watches your days. '
                  'Come back after a week or so.',
              tone: AppTone.info,
            );
          }
          return _Loaded(
            insights: insights,
            calendar: (state as TrackerLoaded).calendar,
          );
        },
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.insights, required this.calendar});

  final OlcInsights insights;
  final List<ContributionDay> calendar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _Era(insights: insights),
        const SizedBox(height: AppSpacing.xxl),
        _Impact(insights: insights),
        const SizedBox(height: AppSpacing.xxl),
        _Rhythm(insights: insights),
        const SizedBox(height: AppSpacing.xxl),
        _Composition(insights: insights),
        const SizedBox(height: AppSpacing.xxl),
        _History(insights: insights),
        const SizedBox(height: AppSpacing.xxl),
        _Trend(insights: insights),
        const SizedBox(height: AppSpacing.massive),
      ],
    );
  }
}

class _Era extends StatelessWidget {
  const _Era({required this.insights});

  final OlcInsights insights;

  @override
  Widget build(BuildContext context) {
    final i = insights;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            eyebrow: '${i.daysTracked} days of history',
            title: 'Your year on GitHub',
            subtitle: i.daysWatched == 0
                ? 'This app started watching today.'
                : 'This app has been watching for ${i.daysWatched} '
                      '${i.daysWatched == 1 ? "day" : "days"}.',
          ),
          const SizedBox(height: AppSpacing.lg),
          StatTileRow(
            tiles: [
              StatTile(
                value: '${i.daysWithContributions}',
                label: 'Active days',
                tone: AppTone.accent,
                emphasis: StatEmphasis.compact,
              ),
              StatTile(
                value: '${(i.consistency * 100).round()}%',
                label: 'Consistency',
                emphasis: StatEmphasis.compact,
              ),
              StatTile(
                value: '${i.longestStreakInEra}',
                label: 'Best run',
                emphasis: StatEmphasis.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The app justifying its own existence in a number.
class _Impact extends StatelessWidget {
  const _Impact({required this.insights});

  final OlcInsights insights;

  @override
  Widget build(BuildContext context) {
    final i = insights;
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Impact',
          subtitle:
              'Days that were empty when we nudged, and had '
              'contributions by the deadline.',
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          tone: i.saves > 0 ? AppTone.accent : null,
          accentEdge: i.saves > 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatTile(
                value: i.remindersSent == 0 ? '—' : '${i.saves}',
                label: i.remindersSent == 0
                    ? 'no reminders sent yet'
                    : (i.saves == 1 ? 'streak saved' : 'streaks saved'),
                tone: i.remindersSent == 0 ? AppTone.neutral : AppTone.accent,
                emphasis: StatEmphasis.hero,
              ),
              const SizedBox(height: AppSpacing.lg),
              Divider(color: t.border, height: 1),
              const SizedBox(height: AppSpacing.lg),
              StatTileRow(
                tiles: [
                  StatTile(
                    value: '${i.remindersSent}',
                    label: 'Reminders',
                    emphasis: StatEmphasis.compact,
                  ),
                  StatTile(
                    value: _dur(i.medianResponseTime),
                    label: 'Median reply',
                    emphasis: StatEmphasis.compact,
                  ),
                  StatTile(
                    value: _dur(i.closestCall),
                    label: 'Closest call',
                    tone: AppTone.warning,
                    emphasis: StatEmphasis.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _dur(Duration? d) {
    if (d == null) return '—';
    if (d.inHours >= 1) return '${d.inHours}h';
    return '${d.inMinutes}m';
  }
}

class _Rhythm extends StatelessWidget {
  const _Rhythm({required this.insights});

  final OlcInsights insights;

  @override
  Widget build(BuildContext context) {
    final i = insights;
    final t = context.tokens;
    final peak = i.peakHour;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Rhythm',
          subtitle: peak == null
              ? 'Timing is only known for recent activity in repositories we '
                    'can read.'
              : 'You are a ${peak.toString().padLeft(2, "0")}:00 committer.',
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BY HOUR',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: t.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              HistogramChart(
                values: i.hourHistogram,
                // Every sixth tick: a label under all 24 bars is unreadable.
                labelFor: (h) => h % 6 == 0 ? '$h' : null,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'BY WEEKDAY',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: t.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              HistogramChart(
                values: i.weekdayHistogram,
                height: 80,
                labelFor: (d) => const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Composition extends StatelessWidget {
  const _Composition({required this.insights});

  final OlcInsights insights;

  @override
  Widget build(BuildContext context) {
    final i = insights;
    final t = context.tokens;
    final total = i.composition.values.fold<int>(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'What the work was',
          subtitle: 'Commits are only one of the four things that count.',
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final type in ContributionType.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _Bar(
                    label: _label(type),
                    value: i.composition[type] ?? 0,
                    total: total,
                  ),
                ),
              if (i.uncountedPushes > 0) ...[
                Divider(color: t.border, height: AppSpacing.xl),
                Row(
                  children: [
                    Icon(Icons.block, size: 14, color: t.warning),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${(i.uncountedShare * 100).round()}% of your pushes '
                        'earned no square',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: t.warning),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _label(ContributionType t) => switch (t) {
    ContributionType.commit => 'Commits',
    ContributionType.issue => 'Issues',
    ContributionType.pullRequest => 'Pull requests',
    ContributionType.review => 'Reviews',
  };
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, required this.total});

  final String label;
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final share = total == 0 ? 0.0 : value / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: text.bodySmall)),
            Text(
              '$value',
              style: text.bodySmall?.copyWith(color: t.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 4,
            backgroundColor: t.surfaceSubtle,
            valueColor: AlwaysStoppedAnimation(t.accent),
          ),
        ),
      ],
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.insights});

  final OlcInsights insights;

  @override
  Widget build(BuildContext context) {
    final breaks = insights.breaks;
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Streak history'),
        const SizedBox(height: AppSpacing.md),
        if (breaks.isEmpty)
          AppCard(
            tone: AppTone.accent,
            child: Row(
              children: [
                Icon(Icons.verified_outlined, size: 18, color: t.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'No breaks since you installed.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else
          ...breaks.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Broke on ${b.brokeOn}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${b.lengthBefore} days before it',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: t.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    AppPill(
                      label: b.hasRecovered ? 'Recovered' : 'Open',
                      tone: b.hasRecovered ? AppTone.accent : AppTone.danger,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Trend extends StatelessWidget {
  const _Trend({required this.insights});

  final OlcInsights insights;

  @override
  Widget build(BuildContext context) {
    final rolling = insights.rollingWeekAverage;
    if (rolling.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Trend',
          subtitle: 'Rolling seven-day average.',
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: TrendChart(values: [for (final v in rolling) v.round()]),
        ),
      ],
    );
  }
}
