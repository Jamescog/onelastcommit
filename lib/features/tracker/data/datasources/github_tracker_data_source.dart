import '../../../../core/github/github_client.dart';
import '../../domain/entities/entities.dart';
import 'tracker_data_source.dart';

/// Reads contributions straight from GitHub's GraphQL API.
///
/// Every shape here was verified against the live API before it was written;
/// the recorded response is in test/fixtures/contributions_response.json. Three
/// findings drove the parsing:
///
/// - Contribution nodes can be entirely null, not merely have null fields. On
///   the account this was verified against, 10 of 11 pullRequestContributions
///   nodes were null — PRs the token cannot see. Skipping nulls is the normal
///   path, not defensive padding.
/// - `contributionLevel` quartiles are relative to the user's own
///   distribution, so the enum is mapped verbatim rather than derived from a
///   count. Deriving would disagree with the user's profile page.
/// - The calendar is the authority on totals. The typed counts do not sum to
///   it, because private work lands in the calendar and not the breakdown.
class GitHubTrackerDataSource implements TrackerDataSource {
  const GitHubTrackerDataSource({required this.client});

  final GitHubClient client;

  /// A single query caps at one year, so a longer window is stitched from
  /// several.
  static const maxWindow = Duration(days: 364);

  static const _query = r'''
query($from: DateTime!, $to: DateTime!) {
  viewer {
    login name bio location avatarUrl
    followers { totalCount }
    following { totalCount }
    repositories(privacy: PUBLIC) { totalCount }
    contributionsCollection(from: $from, to: $to) {
      restrictedContributionsCount
      totalCommitContributions
      totalIssueContributions
      totalPullRequestContributions
      totalPullRequestReviewContributions
      contributionCalendar {
        totalContributions
        weeks { contributionDays { date contributionCount contributionLevel } }
      }
      commitContributionsByRepository(maxRepositories: 25) {
        repository {
          nameWithOwner isPrivate isFork pushedAt
          primaryLanguage { name }
        }
        contributions { totalCount }
      }
      issueContributions(first: 20) {
        nodes { occurredAt issue { id title url repository { nameWithOwner isPrivate } } }
      }
      pullRequestContributions(first: 20) {
        nodes { occurredAt pullRequest { id title url repository { nameWithOwner isPrivate } } }
      }
      pullRequestReviewContributions(first: 20) {
        nodes { occurredAt pullRequest { id title url repository { nameWithOwner isPrivate } } }
      }
    }
  }
}
''';

  Future<Map<String, dynamic>> _fetch({
    required DateTime from,
    required DateTime to,
  }) async {
    final data = await client.query(
      _query,
      variables: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
    return data['viewer'] as Map<String, dynamic>;
  }

  @override
  Future<GitHubProfile> getProfile() async {
    final now = DateTime.now().toUtc();
    return parseProfile(
      await _fetch(from: now.subtract(const Duration(days: 1)), to: now),
    );
  }

  @override
  Future<List<ContributionDay>> getCalendar({
    DateTime? from,
    DateTime? to,
  }) async {
    final end = to ?? DateTime.now().toUtc();
    final start = from ?? end.subtract(maxWindow);

    // Stitch successive one-year windows. Days are keyed by date so an overlap
    // at a boundary resolves to one entry rather than a duplicate.
    final byDate = <String, ContributionDay>{};
    var cursor = start;
    while (cursor.isBefore(end)) {
      final chunkEnd = cursor.add(maxWindow).isAfter(end)
          ? end
          : cursor.add(maxWindow);
      final viewer = await _fetch(from: cursor, to: chunkEnd);
      for (final day in parseCalendar(viewer)) {
        byDate[day.date] = day;
      }
      cursor = chunkEnd.add(const Duration(days: 1));
    }

    final days = byDate.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return days;
  }

  @override
  Future<List<ContributionActivity>> getActivity({int limit = 20}) async {
    final now = DateTime.now().toUtc();
    final items = parseActivity(
      await _fetch(from: now.subtract(const Duration(days: 30)), to: now),
    );
    return items.length <= limit ? items : items.sublist(0, limit);
  }

  @override
  Future<List<RepoContribution>> getRepos() async {
    final now = DateTime.now().toUtc();
    return parseRepos(await _fetch(from: now.subtract(maxWindow), to: now));
  }

  @override
  Future<List<ReminderEvent>> getReminderHistory() async {
    // Local history. GitHub has no idea this exists, so the mirror is the only
    // source and there is nothing to fetch.
    return const [];
  }

  // --- Parsing, kept static so it can be exercised against a recorded
  // response without a client. ---

  static GitHubProfile parseProfile(Map<String, dynamic> viewer) {
    return GitHubProfile(
      login: viewer['login'] as String,
      name: (viewer['name'] as String?) ?? viewer['login'] as String,
      avatarUrl: viewer['avatarUrl'] as String?,
      bio: viewer['bio'] as String?,
      location: viewer['location'] as String?,
      followers: _count(viewer['followers']),
      following: _count(viewer['following']),
      publicRepos: _count(viewer['repositories']),
    );
  }

  static List<ContributionDay> parseCalendar(Map<String, dynamic> viewer) {
    final weeks =
        (_collection(viewer)['contributionCalendar']
                as Map<String, dynamic>)['weeks']
            as List<dynamic>;

    return [
      for (final week in weeks)
        for (final day
            in (week as Map<String, dynamic>)['contributionDays'] as List)
          ContributionDay(
            // GitHub's own label, carried verbatim. Never re-derived from a
            // timestamp — the calendar decides which day work belongs to.
            date: (day as Map<String, dynamic>)['date'] as String,
            count: (day['contributionCount'] as num).toInt(),
            level: levelFrom(day['contributionLevel'] as String?),
          ),
    ];
  }

  /// Maps GitHub's quartile enum onto 0–4.
  ///
  /// The quartiles are computed against the user's own distribution, so the
  /// same count can be a different level for a different person. Taking the
  /// enum verbatim is what keeps the heatmap identical to their profile page.
  static int levelFrom(String? level) => switch (level) {
    'FIRST_QUARTILE' => 1,
    'SECOND_QUARTILE' => 2,
    'THIRD_QUARTILE' => 3,
    'FOURTH_QUARTILE' => 4,
    _ => 0,
  };

  static List<RepoContribution> parseRepos(Map<String, dynamic> viewer) {
    final byRepo =
        _collection(viewer)['commitContributionsByRepository'] as List<dynamic>;

    final repos = <RepoContribution>[];
    for (final entry in byRepo) {
      if (entry is! Map<String, dynamic>) continue;
      final repo = entry['repository'];
      if (repo is! Map<String, dynamic>) continue;

      repos.add(
        RepoContribution(
          name: repo['nameWithOwner'] as String,
          contributionCount: _count(entry['contributions']),
          lastActivityAt:
              DateTime.tryParse((repo['pushedAt'] as String?) ?? '') ??
              DateTime.now().toUtc(),
          isPrivate: repo['isPrivate'] as bool? ?? false,
          isFork: repo['isFork'] as bool? ?? false,
          primaryLanguage:
              (repo['primaryLanguage'] as Map<String, dynamic>?)?['name']
                  as String?,
        ),
      );
    }
    repos.sort((a, b) => b.contributionCount.compareTo(a.contributionCount));
    return repos;
  }

  static List<ContributionActivity> parseActivity(Map<String, dynamic> viewer) {
    final collection = _collection(viewer);
    final items = <ContributionActivity>[];

    void take(String key, String inner, ContributionType type) {
      final nodes = (collection[key] as Map<String, dynamic>?)?['nodes'];
      if (nodes is! List) return;

      for (final node in nodes) {
        // A whole node is null when the contribution is in a repository this
        // token cannot see. Verified as the common case, not the exception.
        if (node is! Map<String, dynamic>) continue;
        final subject = node[inner];
        if (subject is! Map<String, dynamic>) continue;
        final repo = subject['repository'];
        if (repo is! Map<String, dynamic>) continue;

        items.add(
          ContributionActivity(
            id: subject['id'] as String,
            type: type,
            repoName: repo['nameWithOwner'] as String,
            occurredAt:
                DateTime.tryParse((node['occurredAt'] as String?) ?? '') ??
                DateTime.now().toUtc(),
            title: subject['title'] as String?,
            isPrivate: repo['isPrivate'] as bool? ?? false,
          ),
        );
      }
    }

    take('issueContributions', 'issue', ContributionType.issue);
    take(
      'pullRequestContributions',
      'pullRequest',
      ContributionType.pullRequest,
    );
    take(
      'pullRequestReviewContributions',
      'pullRequest',
      ContributionType.review,
    );

    items.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return items;
  }

  static Map<String, dynamic> _collection(Map<String, dynamic> viewer) =>
      viewer['contributionsCollection'] as Map<String, dynamic>;

  static int _count(Object? connection) =>
      ((connection as Map<String, dynamic>?)?['totalCount'] as num?)?.toInt() ??
      0;
}
