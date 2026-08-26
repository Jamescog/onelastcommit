import 'package:flutter/material.dart';

import '../../../features/tracker/data/datasources/fake_tracker_data_source.dart';
import '../../../features/tracker/domain/entities/entities.dart';
import '../../dev/dev_scenario.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../widgets.dart';

/// Shows exactly what the fake serves for each [Scenario].
///
/// Debug-only. The point is to make every screen state checkable by hand:
/// pick a scenario here, and the screens built in later commits render that
/// situation without a backend or a real streak.
class ScenarioPreviewPage extends StatelessWidget {
  const ScenarioPreviewPage({super.key});

  static const _source = FakeTrackerDataSource();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scenarios')),
      body: ValueListenableBuilder<Scenario>(
        valueListenable: activeScenario,
        builder: (context, scenario, _) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _Picker(scenario: scenario),
              const SizedBox(height: AppSpacing.xl),
              // Keyed on the scenario so every future rebuilds on change.
              _Data(key: ValueKey(scenario), source: _source),
              const SizedBox(height: AppSpacing.massive),
            ],
          );
        },
      ),
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({required this.scenario});

  final Scenario scenario;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final s in Scenario.values)
              ChoiceChip(
                label: Text(s.label),
                selected: s == scenario,
                onSelected: (_) => activeScenario.value = s,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          scenario.description,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
        ),
      ],
    );
  }
}

class _Data extends StatelessWidget {
  const _Data({required this.source, super.key});

  final FakeTrackerDataSource source;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Bundle>(
      future: _load(source),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.md,
            children: [SkeletonCard(), SkeletonCard(lines: 2)],
          );
        }
        if (snap.hasError) {
          return SizedBox(
            height: 260,
            child: ErrorStateView(
              title: 'The source threw',
              message:
                  '${snap.error.runtimeType} — this is the error '
                  'scenario behaving correctly.',
            ),
          );
        }

        final b = snap.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.xl,
          children: [
            _Summary(bundle: b),
            _CalendarStrip(days: b.days),
            _ActivityList(items: b.activity),
            _RepoList(repos: b.repos),
            _ReminderSummary(events: b.reminders),
          ],
        );
      },
    );
  }

  static Future<_Bundle> _load(FakeTrackerDataSource s) async {
    return _Bundle(
      profile: await s.getProfile(),
      days: await s.getCalendar(),
      activity: await s.getActivity(limit: 8),
      repos: await s.getRepos(),
      reminders: await s.getReminderHistory(),
    );
  }
}

class _Bundle {
  const _Bundle({
    required this.profile,
    required this.days,
    required this.activity,
    required this.repos,
    required this.reminders,
  });

  final GitHubProfile profile;
  final List<ContributionDay> days;
  final List<ContributionActivity> activity;
  final List<RepoContribution> repos;
  final List<ReminderEvent> reminders;
}

class _Summary extends StatelessWidget {
  const _Summary({required this.bundle});

  final _Bundle bundle;

  @override
  Widget build(BuildContext context) {
    final days = bundle.days;
    final active = days.where((d) => d.hasContributions).length;
    final today = days.isEmpty ? 0 : days.last.count;

    // A deliberately naive trailing count — the real streak rules, including
    // the pending-today case and the year-boundary stitch, land in commit 7.
    var streak = 0;
    for (var i = days.length - 1; i >= 0; i--) {
      if (i == days.length - 1 && days[i].count == 0) continue;
      if (days[i].count == 0) break;
      streak++;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            eyebrow: '@${bundle.profile.login}',
            title: bundle.profile.name,
          ),
          const SizedBox(height: AppSpacing.lg),
          StatTileRow(
            tiles: [
              StatTile(
                value: '$streak',
                label: 'Trailing streak',
                tone: streak > 0 ? AppTone.accent : AppTone.danger,
                emphasis: StatEmphasis.compact,
              ),
              StatTile(
                value: '$today',
                label: 'Today',
                tone: today > 0 ? AppTone.accent : AppTone.danger,
                emphasis: StatEmphasis.compact,
              ),
              StatTile(
                value: '$active/${days.length}',
                label: 'Active days',
                emphasis: StatEmphasis.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarStrip extends StatelessWidget {
  const _CalendarStrip({required this.days});

  final List<ContributionDay> days;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final recent = days.length > 91 ? days.sublist(days.length - 91) : days;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Calendar',
          subtitle: 'Last 13 weeks. Today carries a ring.',
        ),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: 3,
            children: [
              for (var w = 0; w < recent.length; w += 7)
                Column(
                  spacing: 3,
                  children: [
                    for (final d in recent.skip(w).take(7))
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: t.heatmap[d.level],
                          borderRadius: BorderRadius.circular(3),
                          border: d == recent.last
                              ? Border.all(color: t.textPrimary, width: 2)
                              : null,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.items});

  final List<ContributionActivity> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 220,
        child: EmptyStateView(
          icon: Icons.inbox_outlined,
          title: 'No activity',
          message: 'This scenario has nothing to show yet.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Activity'),
        const SizedBox(height: AppSpacing.md),
        Column(
          spacing: AppSpacing.sm,
          children: [
            for (final a in items)
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title ?? '${a.count} commits',
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            a.repoName,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: context.tokens.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (!a.counted)
                      AppPill(
                        label: a.branch ?? 'uncounted',
                        tone: AppTone.warning,
                        icon: Icons.block,
                      )
                    else
                      AppPill(label: a.type.name, tone: AppTone.neutral),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RepoList extends StatelessWidget {
  const _RepoList({required this.repos});

  final List<RepoContribution> repos;

  @override
  Widget build(BuildContext context) {
    if (repos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Repositories'),
        const SizedBox(height: AppSpacing.md),
        Column(
          spacing: AppSpacing.sm,
          children: [
            for (final r in repos)
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                tone: r.hasUncountedWork ? AppTone.warning : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.name,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (r.isFork)
                      const Padding(
                        padding: EdgeInsets.only(right: AppSpacing.xs),
                        child: AppPill(label: 'fork', tone: AppTone.warning),
                      ),
                    AppPill(label: '${r.contributionCount}'),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ReminderSummary extends StatelessWidget {
  const _ReminderSummary({required this.events});

  final List<ReminderEvent> events;

  @override
  Widget build(BuildContext context) {
    final saved = events
        .where((e) => e.outcome == ReminderOutcome.saved)
        .toList();
    final responses =
        saved.map((e) => e.responseTime).whereType<Duration>().toList()..sort();
    final median = responses.isEmpty ? null : responses[responses.length ~/ 2];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Reminder history',
          subtitle: 'The part GitHub cannot reconstruct.',
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: StatTileRow(
            tiles: [
              StatTile(
                value: '${events.length}',
                label: 'Sent',
                emphasis: StatEmphasis.compact,
              ),
              StatTile(
                value: '${saved.length}',
                label: 'Saves',
                tone: AppTone.accent,
                emphasis: StatEmphasis.compact,
              ),
              StatTile(
                value: median == null ? '—' : '${median.inMinutes}m',
                label: 'Median reply',
                emphasis: StatEmphasis.compact,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
