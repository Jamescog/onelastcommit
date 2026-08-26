import 'dart:convert';

import '../../domain/entities/entities.dart';

/// Row mapping for the local mirror.
///
/// Hand-written rather than generated, matching the rest of the project. Kept
/// in one file so the column names for a table sit next to each other and
/// drift is obvious.
class TrackerRows {
  const TrackerRows._();

  static String? _iso(DateTime? d) => d?.toUtc().toIso8601String();
  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.parse(v as String);

  // --- contribution_days ---

  static Map<String, Object?> dayToRow(ContributionDay d, DateTime takenAt) => {
    'date': d.date,
    'count': d.count,
    'level': d.level,
    'first_contribution_at': _iso(d.firstContributionAt),
    'last_contribution_at': _iso(d.lastContributionAt),
    'counted_pushes': d.countedPushes,
    'uncounted_pushes': d.uncountedPushes,
    'taken_at': _iso(takenAt),
  };

  static ContributionDay dayFromRow(Map<String, Object?> r) => ContributionDay(
    date: r['date']! as String,
    count: r['count']! as int,
    level: r['level']! as int,
    firstContributionAt: _date(r['first_contribution_at']),
    lastContributionAt: _date(r['last_contribution_at']),
    countedPushes: (r['counted_pushes'] as int?) ?? 0,
    uncountedPushes: (r['uncounted_pushes'] as int?) ?? 0,
  );

  // --- contribution_activity ---

  static Map<String, Object?> activityToRow(ContributionActivity a) => {
    'id': a.id,
    'type': a.type.name,
    'repo_name': a.repoName,
    'occurred_at': _iso(a.occurredAt),
    'count': a.count,
    'title': a.title,
    'counted': a.counted ? 1 : 0,
    'branch': a.branch,
    'is_private': a.isPrivate ? 1 : 0,
  };

  static ContributionActivity activityFromRow(Map<String, Object?> r) =>
      ContributionActivity(
        id: r['id']! as String,
        type: ContributionType.values.byName(r['type']! as String),
        repoName: r['repo_name']! as String,
        occurredAt: _date(r['occurred_at'])!,
        count: (r['count'] as int?) ?? 1,
        title: r['title'] as String?,
        counted: (r['counted'] as int?) != 0,
        branch: r['branch'] as String?,
        isPrivate: (r['is_private'] as int?) == 1,
      );

  // --- repo_activity ---

  static Map<String, Object?> repoToRow(RepoContribution r) => {
    'repo_name': r.name,
    'contribution_count': r.contributionCount,
    'uncounted_pushes': r.uncountedPushes,
    'last_activity_at': _iso(r.lastActivityAt),
    'is_private': r.isPrivate ? 1 : 0,
    'is_fork': r.isFork ? 1 : 0,
    'primary_language': r.primaryLanguage,
  };

  static RepoContribution repoFromRow(Map<String, Object?> r) =>
      RepoContribution(
        name: r['repo_name']! as String,
        contributionCount: (r['contribution_count'] as int?) ?? 0,
        lastActivityAt: _date(r['last_activity_at'])!,
        uncountedPushes: (r['uncounted_pushes'] as int?) ?? 0,
        isPrivate: (r['is_private'] as int?) == 1,
        isFork: (r['is_fork'] as int?) == 1,
        primaryLanguage: r['primary_language'] as String?,
      );

  // --- reminder_events ---

  static Map<String, Object?> reminderToRow(ReminderEvent e) => {
    'id': e.id,
    'sent_at': _iso(e.sentAt),
    'streak_at_send': e.streakAtSend,
    'contributions_at_send': e.contributionsAtSend,
    'hours_left': e.hoursLeft,
    'outcome': e.outcome.name,
    'outcome_at': _iso(e.outcomeAt),
  };

  static ReminderEvent reminderFromRow(Map<String, Object?> r) => ReminderEvent(
    id: r['id']! as String,
    sentAt: _date(r['sent_at'])!,
    streakAtSend: (r['streak_at_send'] as int?) ?? 0,
    contributionsAtSend: (r['contributions_at_send'] as int?) ?? 0,
    outcome: ReminderOutcome.values.byName(r['outcome']! as String),
    hoursLeft: r['hours_left'] as int?,
    outcomeAt: _date(r['outcome_at']),
  );

  // --- profile, held as JSON in sync_state ---

  static String profileToJson(GitHubProfile p) => jsonEncode({
    'login': p.login,
    'name': p.name,
    'avatarUrl': p.avatarUrl,
    'bio': p.bio,
    'location': p.location,
    'followers': p.followers,
    'following': p.following,
    'publicRepos': p.publicRepos,
  });

  static GitHubProfile profileFromJson(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return GitHubProfile(
      login: m['login'] as String,
      name: m['name'] as String,
      avatarUrl: m['avatarUrl'] as String?,
      bio: m['bio'] as String?,
      location: m['location'] as String?,
      followers: (m['followers'] as int?) ?? 0,
      following: (m['following'] as int?) ?? 0,
      publicRepos: (m['publicRepos'] as int?) ?? 0,
    );
  }
}
