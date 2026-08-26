import '../../domain/entities/entities.dart';

/// Raw contribution data, before any streak or insight maths.
///
/// Two implementations exist by design: the fake used through Phase 1, and the
/// GitHub-backed one that arrives in Phase 2. Both return the same shapes, so
/// swapping them is a registration change rather than a rewrite.
///
/// Note what is *not* here: [StreakStatus] and [OlcInsights]. Those are derived
/// on the client from the days and the reminder history, so there is exactly
/// one implementation of the streak rules and it stays available offline.
abstract class TrackerDataSource {
  Future<GitHubProfile> getProfile();

  /// Contribution days, oldest first. GitHub caps a single query at one year,
  /// so a longer range is stitched from several.
  Future<List<ContributionDay>> getCalendar({DateTime? from, DateTime? to});

  Future<List<ContributionActivity>> getActivity({int limit = 20});

  Future<List<RepoContribution>> getRepos();

  /// Reminders sent and what became of them. Local history — GitHub has no
  /// idea this exists.
  Future<List<ReminderEvent>> getReminderHistory();
}
