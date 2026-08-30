import '../../../../core/github/github_client.dart';
import '../../../../core/util/utc_date.dart';
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

  /// How many repositories to pull commit history for.
  ///
  /// One query per repository, so this bounds sync cost. Against a 5,000/hour
  /// budget ten queries is nothing, but sync time scales with it, so the
  /// busiest repositories are fetched and the tail is left to the calendar.
  static const historyRepoLimit = 10;

  static const _historyQuery = r'''
query($owner: String!, $name: String!, $since: GitTimestamp!) {
  repository(owner: $owner, name: $name) {
    nameWithOwner
    isPrivate
    defaultBranchRef {
      name
      target {
        ... on Commit {
          history(first: 60, since: $since) {
            nodes {
              oid messageHeadline committedDate additions deletions
              author { user { login } }
            }
          }
        }
      }
    }
  }
}
''';

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

    return _enrichRecent(days);
  }

  /// Adds wall-clock times and uncounted pushes to the most recent days.
  ///
  /// The calendar carries neither. Times come from commit history — the events
  /// feed's PushEvent payload no longer carries commits at all — and only the
  /// recent window is enriched, because a query per repository is not worth
  /// spending on a year of history nobody scrolls to.
  Future<List<ContributionDay>> _enrichRecent(
    List<ContributionDay> days,
  ) async {
    if (days.isEmpty) return days;

    final now = DateTime.now().toUtc();
    final since = now.subtract(const Duration(days: 30));

    final List<ContributionActivity> commits;
    final Map<String, int> uncounted;
    try {
      final viewer = await _fetch(from: since, to: now);
      commits = await _commitActivity(viewer, since);
      uncounted = await _uncountedByDate(viewer['login'] as String);
    } catch (_) {
      // Enrichment is a bonus. Losing it must not lose the calendar, which is
      // the only thing the streak actually depends on.
      return days;
    }

    final firstAt = <String, DateTime>{};
    final lastAt = <String, DateTime>{};
    for (final c in commits) {
      final key = utcDateLabel(c.occurredAt);
      final first = firstAt[key];
      final last = lastAt[key];
      if (first == null || c.occurredAt.isBefore(first)) {
        firstAt[key] = c.occurredAt;
      }
      if (last == null || c.occurredAt.isAfter(last)) {
        lastAt[key] = c.occurredAt;
      }
    }

    return [
      for (final day in days)
        if (firstAt.containsKey(day.date) || uncounted.containsKey(day.date))
          ContributionDay(
            date: day.date,
            count: day.count,
            level: day.level,
            firstContributionAt: firstAt[day.date],
            lastContributionAt: lastAt[day.date],
            countedPushes: day.count,
            uncountedPushes: uncounted[day.date] ?? 0,
          )
        else
          day,
    ];
  }

  /// Best-effort count of pushes that earned no square, by date.
  ///
  /// Deliberately incomplete. GitHub trimmed the PushEvent payload to refs and
  /// ids, and the public feed omits private work entirely — on the account
  /// this was built against it held 4 events for a day the calendar scored 19.
  /// What survives is the branch name, which is enough to spot the most common
  /// cause: work pushed somewhere the graph does not count. The UI must
  /// present this as recent public pushes, never as a complete accounting.
  Future<Map<String, int>> _uncountedByDate(String login) async {
    final events = await client.getList('/users/$login/events?per_page=100');
    if (events == null) return const {};

    final byDate = <String, int>{};
    for (final event in events) {
      if (event is! Map<String, dynamic>) continue;
      if (event['type'] != 'PushEvent') continue;

      final ref = (event['payload'] as Map<String, dynamic>?)?['ref'];
      if (ref is! String) continue;
      final branch = ref.split('/').last;
      // Without the repo's default branch to hand, the conventional names are
      // the only signal available.
      if (branch == 'main' || branch == 'master') continue;

      final at = DateTime.tryParse((event['created_at'] as String?) ?? '');
      if (at == null) continue;
      final key = utcDateLabel(at);
      byDate[key] = (byDate[key] ?? 0) + 1;
    }
    return byDate;
  }

  @override
  Future<List<ContributionActivity>> getActivity({int limit = 20}) async {
    final now = DateTime.now().toUtc();
    final since = now.subtract(const Duration(days: 30));
    final viewer = await _fetch(from: since, to: now);

    // Issues, PRs and reviews come from the contributions collection; commits
    // come from repository history. The events feed used to carry commit
    // messages and no longer does — its PushEvent payload has been trimmed to
    // refs and ids — so history is the only source for what was actually
    // written.
    final items = parseActivity(viewer)
      ..addAll(await _commitActivity(viewer, since));

    items.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return items.length <= limit ? items : items.sublist(0, limit);
  }

  /// Commit history for the repositories with the most contributions.
  Future<List<ContributionActivity>> _commitActivity(
    Map<String, dynamic> viewer,
    DateTime since,
  ) async {
    final login = viewer['login'] as String;
    final repos = parseRepos(viewer).take(historyRepoLimit);
    final commits = <ContributionActivity>[];

    for (final repo in repos) {
      final parts = repo.name.split('/');
      if (parts.length != 2) continue;
      try {
        final data = await client.query(
          _historyQuery,
          variables: {
            'owner': parts.first,
            'name': parts.last,
            'since': since.toUtc().toIso8601String(),
          },
        );
        commits.addAll(parseHistory(data, login: login));
      } catch (_) {
        // One unreadable repository must not lose the others. A repo can
        // vanish or lose access between the two queries.
        continue;
      }
    }
    return commits;
  }

  /// Commits authored by [login] on a repository's default branch.
  ///
  /// The author filter matters: history on a shared repository is everyone's,
  /// and counting a colleague's commits as the user's would inflate every
  /// number on the analysis page.
  static List<ContributionActivity> parseHistory(
    Map<String, dynamic> data, {
    required String login,
  }) {
    final repo = data['repository'];
    if (repo is! Map<String, dynamic>) return const [];
    final branch = repo['defaultBranchRef'];
    if (branch is! Map<String, dynamic>) return const [];
    final target = branch['target'];
    if (target is! Map<String, dynamic>) return const [];
    final nodes = (target['history'] as Map<String, dynamic>?)?['nodes'];
    if (nodes is! List) return const [];

    final name = repo['nameWithOwner'] as String;
    final isPrivate = repo['isPrivate'] as bool? ?? false;
    final out = <ContributionActivity>[];

    for (final node in nodes) {
      if (node is! Map<String, dynamic>) continue;
      final author =
          ((node['author'] as Map<String, dynamic>?)?['user']
              as Map<String, dynamic>?)?['login'];
      if (author != login) continue;

      final oid = node['oid'] as String? ?? '';
      final committedRaw = (node['committedDate'] as String?) ?? '';
      out.add(
        ContributionActivity(
          id: oid.isEmpty ? '$name@$committedRaw' : oid,
          type: ContributionType.commit,
          repoName: name,
          occurredAt: DateTime.tryParse(committedRaw) ?? DateTime.now().toUtc(),
          title: node['messageHeadline'] as String?,
          isPrivate: isPrivate,
          sha: oid.isEmpty ? null : oid.substring(0, 7),
          additions: (node['additions'] as num?)?.toInt(),
          deletions: (node['deletions'] as num?)?.toInt(),
        ),
      );
    }
    return out;
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
