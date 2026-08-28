import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:olc/features/tracker/data/datasources/github_tracker_data_source.dart';
import 'package:olc/features/tracker/domain/entities/entities.dart';

/// Parses a response recorded from the live API.
///
/// The fixture is a real GitHub reply, trimmed but not sanitised into
/// convenience: it keeps the null contribution nodes, all five quartile
/// levels, and a private repository. Hand-written fixtures would have omitted
/// exactly the cases that break a parser.
void main() {
  final viewer =
      (jsonDecode(
                File(
                  'test/fixtures/contributions_response.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>)['data']['viewer']
          as Map<String, dynamic>;

  test('profile parses', () {
    final p = GitHubTrackerDataSource.parseProfile(viewer);
    expect(p.login, isNotEmpty);
    expect(p.name, isNotEmpty);
    expect(p.followers, greaterThanOrEqualTo(0));
    expect(p.initial, isNotEmpty);
  });

  group('calendar', () {
    test('every day parses and dates are carried verbatim', () {
      final days = GitHubTrackerDataSource.parseCalendar(viewer);
      expect(days, isNotEmpty);
      for (final d in days) {
        // GitHub's own YYYY-MM-DD label, never re-derived.
        expect(d.date, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
        expect(d.level, inInclusiveRange(0, 4));
        expect(d.count, greaterThanOrEqualTo(0));
      }
    });

    test('a zero-count day is level 0 and a non-zero day never is', () {
      for (final d in GitHubTrackerDataSource.parseCalendar(viewer)) {
        expect(d.level == 0, d.count == 0, reason: 'on ${d.date}');
      }
    });

    test('quartile enum maps verbatim rather than being derived', () {
      // The quartiles are relative to the user's own distribution, so the same
      // count can be a different level for a different account. Deriving a
      // level from a count would disagree with the profile page.
      expect(GitHubTrackerDataSource.levelFrom('NONE'), 0);
      expect(GitHubTrackerDataSource.levelFrom('FIRST_QUARTILE'), 1);
      expect(GitHubTrackerDataSource.levelFrom('SECOND_QUARTILE'), 2);
      expect(GitHubTrackerDataSource.levelFrom('THIRD_QUARTILE'), 3);
      expect(GitHubTrackerDataSource.levelFrom('FOURTH_QUARTILE'), 4);
      expect(GitHubTrackerDataSource.levelFrom(null), 0);
      expect(GitHubTrackerDataSource.levelFrom('SOMETHING_NEW'), 0);
    });

    test('the fixture exercises all five levels', () {
      final levels = GitHubTrackerDataSource.parseCalendar(
        viewer,
      ).map((d) => d.level).toSet();
      expect(levels, containsAll([0, 1, 2, 3, 4]));
    });
  });

  group('activity', () {
    test('null nodes are skipped rather than crashing', () {
      // 4 of the 5 PR nodes in this fixture are null — contributions in
      // repositories the token cannot see. This is the common case.
      final items = GitHubTrackerDataSource.parseActivity(viewer);
      expect(items, isNotEmpty);
      for (final a in items) {
        expect(a.id, isNotEmpty);
        expect(a.repoName, contains('/'));
      }
    });

    test('is ordered newest first', () {
      final items = GitHubTrackerDataSource.parseActivity(viewer);
      for (var i = 1; i < items.length; i++) {
        expect(items[i - 1].occurredAt.isBefore(items[i].occurredAt), isFalse);
      }
    });
  });

  group('repos', () {
    test('parse with their flags, ordered by contribution count', () {
      final repos = GitHubTrackerDataSource.parseRepos(viewer);
      expect(repos, isNotEmpty);
      for (var i = 1; i < repos.length; i++) {
        expect(
          repos[i - 1].contributionCount,
          greaterThanOrEqualTo(repos[i].contributionCount),
        );
      }
      expect(repos.first.name, contains('/'));
    });
  });

  test('the calendar total is the authority, not the typed breakdown', () {
    // Verified against the live API: commits+issues+PRs+reviews = 627 while
    // the calendar reports 735, because private work lands in the calendar and
    // not the breakdown. Nothing may present the breakdown as summing to the
    // total.
    final c = viewer['contributionsCollection'] as Map<String, dynamic>;
    final typed =
        (c['totalCommitContributions'] as num) +
        (c['totalIssueContributions'] as num) +
        (c['totalPullRequestContributions'] as num) +
        (c['totalPullRequestReviewContributions'] as num);
    final calendarTotal =
        (c['contributionCalendar']
                as Map<String, dynamic>)['totalContributions']
            as num;
    expect(typed, isNot(equals(calendarTotal)));
  });

  test('domain entities survive the round trip', () {
    final days = GitHubTrackerDataSource.parseCalendar(viewer);
    expect(days.first, isA<ContributionDay>());
    expect(
      GitHubTrackerDataSource.parseActivity(viewer).first,
      isA<ContributionActivity>(),
    );
  });
}
