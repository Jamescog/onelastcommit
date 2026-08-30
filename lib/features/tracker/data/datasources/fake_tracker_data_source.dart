import 'dart:math';

import '../../../../core/dev/dev_scenario.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/util/utc_date.dart';
import '../../domain/entities/entities.dart';
import 'tracker_data_source.dart';

/// Generates a plausible year of contribution history for the active
/// [Scenario].
///
/// Seeded per scenario, so the same scenario always produces the same data.
/// A fake that shuffles on every hot reload makes UI work harder, not easier —
/// you can never tell whether a layout changed because of your edit or because
/// the numbers moved.
class FakeTrackerDataSource implements TrackerDataSource {
  const FakeTrackerDataSource();

  Scenario get _scenario => activeScenario.value;

  static const _repoNames = [
    'jamescog/onelastcommit',
    'jamescog/dotfiles',
    'jamescog/flutter-widgets',
    'acme/payments-api',
    'acme/design-system',
  ];

  static const _commitMessages = [
    'fix: seal contribution days past their UTC deadline',
    'feat: add rolling seven-day average to the trend chart',
    'refactor: move streak rules into the domain layer',
    'fix: countdown no longer goes negative after midnight',
    'chore: bump go_router to 16.2.4',
    'feat: warn when a reminder falls after the UTC deadline',
    'fix: heatmap today-ring vanished against the accent ramp',
    'test: cover the pending-today rule',
    'docs: explain why push events are the wrong signal',
    'perf: batch calendar writes into one transaction',
    'fix: settings bloc no longer spins forever on cache failure',
    'feat: surface uncounted pushes on the repos tab',
  ];

  static const _issueTitles = [
    'Streak resets an hour early in UTC+13',
    'Heatmap tooltip clipped on small screens',
    'Add reduce-motion support to skeletons',
    'Cache is not invalidated after a manual sync',
  ];

  void _guard() {
    if (_scenario == Scenario.error) {
      throw CacheException();
    }
  }

  /// UTC midnight for a day offset back from today. Contribution days are
  /// labelled in UTC, so everything here is anchored there rather than local.
  static DateTime _dayUtc(int daysAgo) {
    final now = DateTime.now().toUtc();
    return DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysAgo));
  }

  static int _levelFor(int count) {
    if (count == 0) return 0;
    if (count <= 2) return 1;
    if (count <= 4) return 2;
    if (count <= 7) return 3;
    return 4;
  }

  /// How long the current streak should run, and what today looks like.
  ({int streak, int today}) get _shape => switch (_scenario) {
    Scenario.healthy => (streak: 47, today: 5),
    Scenario.atRisk => (streak: 47, today: 0),
    Scenario.brokenYesterday => (streak: 0, today: 0),
    Scenario.brandNewUser => (streak: 0, today: 0),
    Scenario.longStreak => (streak: 312, today: 3),
    Scenario.offline => (streak: 47, today: 0),
    Scenario.error => (streak: 0, today: 0),
  };

  @override
  Future<GitHubProfile> getProfile() async {
    _guard();
    if (_scenario == Scenario.brandNewUser) {
      return const GitHubProfile(
        login: 'newcommitter',
        name: 'New Committer',
        publicRepos: 2,
      );
    }
    return const GitHubProfile(
      login: 'jamescog',
      name: 'James Cog',
      bio: 'Flutter and Dart. Building One Last Commit.',
      location: 'Addis Ababa',
      followers: 234,
      following: 189,
      publicRepos: 47,
    );
  }

  @override
  Future<List<ContributionDay>> getCalendar({
    DateTime? from,
    DateTime? to,
  }) async {
    _guard();
    final rand = Random(_scenario.index * 7919);
    final shape = _shape;
    final span = _scenario == Scenario.brandNewUser ? 30 : 365;

    final days = <ContributionDay>[];
    for (var ago = span - 1; ago >= 0; ago--) {
      final date = _dayUtc(ago);
      final count = _countFor(ago, shape, rand, date);

      // A slice of pushed work never earns a square: feature branches, forks,
      // commits from an unregistered email. This is the gap the app exists to
      // surface, so the fake has to contain it.
      final uncounted = rand.nextInt(10) == 0 ? 1 + rand.nextInt(2) : 0;

      days.add(
        ContributionDay(
          date: utcDateLabel(date),
          count: count,
          level: _levelFor(count),
          firstContributionAt: count == 0
              ? null
              : date.add(Duration(hours: 9 + rand.nextInt(6))),
          lastContributionAt: count == 0
              ? null
              : date.add(Duration(hours: 19 + rand.nextInt(5))),
          countedPushes: count,
          uncountedPushes: uncounted,
        ),
      );
    }
    return days;
  }

  int _countFor(
    int ago,
    ({int streak, int today}) shape,
    Random rand,
    DateTime date,
  ) {
    if (ago == 0) return shape.today;

    if (_scenario == Scenario.brandNewUser) {
      return rand.nextInt(4) == 0 ? 1 + rand.nextInt(3) : 0;
    }

    // The break itself: yesterday empty, a 23-day run before it.
    if (_scenario == Scenario.brokenYesterday) {
      if (ago == 1) return 0;
      if (ago <= 24) return 1 + rand.nextInt(6);
      return rand.nextInt(3) == 0 ? 0 : 1 + rand.nextInt(5);
    }

    // Inside the current streak, every day must be non-zero or the streak the
    // scenario claims would not actually hold.
    if (ago <= shape.streak) return 1 + rand.nextInt(8);

    // Before it: weekday-heavier, with real gaps.
    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final skipChance = isWeekend ? 6 : 3;
    if (rand.nextInt(10) < skipChance) return 0;
    return 1 + rand.nextInt(isWeekend ? 4 : 7);
  }

  @override
  Future<List<ContributionActivity>> getActivity({int limit = 20}) async {
    _guard();
    if (_scenario == Scenario.brandNewUser) return const [];

    final rand = Random(_scenario.index * 104729);
    final shape = _shape;
    final items = <ContributionActivity>[];

    // Today's items first — an at-risk day genuinely has none, which is the
    // empty state the Today tab must render.
    for (var i = 0; i < shape.today; i++) {
      items.add(
        ContributionActivity(
          id: 'today-$i',
          type: ContributionType.commit,
          repoName: _repoNames[rand.nextInt(_repoNames.length)],
          occurredAt: DateTime.now().subtract(Duration(hours: i * 2 + 1)),
          count: 1 + rand.nextInt(4),
          title: _commitMessages[rand.nextInt(_commitMessages.length)],
        ),
      );
    }

    for (var i = items.length; i < limit; i++) {
      final type = ContributionType.values[rand.nextInt(4)];
      final counted = rand.nextInt(8) != 0;
      items.add(
        ContributionActivity(
          id: 'past-$i',
          type: type,
          repoName: _repoNames[rand.nextInt(_repoNames.length)],
          occurredAt: DateTime.now().subtract(
            Duration(hours: 8 + i * 5, minutes: rand.nextInt(60)),
          ),
          count: type == ContributionType.commit ? 1 + rand.nextInt(5) : 1,
          title: type == ContributionType.commit
              ? _commitMessages[rand.nextInt(_commitMessages.length)]
              : _issueTitles[rand.nextInt(_issueTitles.length)],
          counted: counted,
          branch: counted ? null : 'feature/refactor-tokens',
          isPrivate: rand.nextInt(5) == 0,
        ),
      );
    }
    return items;
  }

  @override
  Future<List<RepoContribution>> getRepos() async {
    _guard();
    if (_scenario == Scenario.brandNewUser) return const [];

    final rand = Random(_scenario.index * 15485863);
    return [
      for (var i = 0; i < _repoNames.length; i++)
        RepoContribution(
          name: _repoNames[i],
          contributionCount: 120 - i * 21 + rand.nextInt(12),
          lastActivityAt: DateTime.now().subtract(Duration(hours: i * 9 + 2)),
          uncountedPushes: i == 2 ? 14 : rand.nextInt(3),
          isPrivate: i >= 3,
          isFork: i == 2,
          primaryLanguage: const [
            'Dart',
            'Shell',
            'Dart',
            'Go',
            'TypeScript',
          ][i],
        ),
    ];
  }

  @override
  Future<List<ReminderEvent>> getReminderHistory() async {
    _guard();
    if (_scenario == Scenario.brandNewUser) return const [];

    final rand = Random(_scenario.index * 32452843);
    final events = <ReminderEvent>[];
    final span = _scenario == Scenario.longStreak ? 120 : 62;

    for (var ago = span; ago >= 1; ago--) {
      // Not every day earns a reminder — most days the user has already
      // contributed by the time the window opens.
      if (rand.nextInt(10) < 6) continue;

      final sentAt = _dayUtc(ago).add(Duration(hours: 20, minutes: 30));
      final outcome = switch (rand.nextInt(10)) {
        0 => ReminderOutcome.broken,
        1 => ReminderOutcome.unknown,
        2 || 3 => ReminderOutcome.alreadySafe,
        _ => ReminderOutcome.saved,
      };

      events.add(
        ReminderEvent(
          id: 'rem-$ago',
          sentAt: sentAt,
          streakAtSend: max(0, _shape.streak - ago),
          contributionsAtSend: outcome == ReminderOutcome.alreadySafe ? 2 : 0,
          outcome: outcome,
          hoursLeft: 3,
          outcomeAt: outcome == ReminderOutcome.saved
              ? sentAt.add(Duration(minutes: 6 + rand.nextInt(150)))
              : null,
        ),
      );
    }
    return events;
  }
}
