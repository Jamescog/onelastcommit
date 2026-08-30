import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/entities.dart';
import '../services/reminder_journal.dart';

/// Reads come from the local mirror, always. [sync] is a background write that
/// refreshes that mirror; no screen waits on it.
///
/// This is what makes offline work without an offline mode — online and
/// offline take the same path, and the only difference is the [DataFreshness]
/// riding along with the result. See PLAN.md section 4.
abstract class TrackerRepository {
  Future<Either<Failure, GitHubProfile>> getProfile();

  /// The core object. Drives the Today tab and every reminder decision.
  Future<Either<Failure, StreakStatus>> getStreak();

  /// Contribution calendar for a date range. Defaults to the trailing year,
  /// which is the most a single GitHub query will return.
  Future<Either<Failure, List<ContributionDay>>> getCalendar({
    DateTime? from,
    DateTime? to,
  });

  Future<Either<Failure, List<ContributionActivity>>> getActivity({
    int limit = 20,
  });

  Future<Either<Failure, List<RepoContribution>>> getRepos();

  /// Analysis-page aggregates, computed locally from the OLC-era history.
  Future<Either<Failure, OlcInsights>> getInsights();

  /// Records the reminders that have fired since this last ran, and resolves
  /// the outcome of every one still open.
  ///
  /// The single entry point for reminder history: app start, app foreground
  /// and Phase 3's periodic background check all call this and nothing else.
  /// It is local-only and idempotent, so calling it more often costs a
  /// database read and changes nothing. Run it *after* a refresh — the
  /// answers it can reach are only as good as the mirror it reads.
  Future<Either<Failure, ReminderCheck>> recordReminderOutcomes();

  /// Refresh the mirror. Returns the freshness that resulted, so a caller can
  /// tell a successful refresh from a silent fall back to cache.
  Future<Either<Failure, DataFreshness>> sync();

  /// Empties the mirror and leaves it empty. Sign-out only.
  ///
  /// Unlike every other reset here this takes the reminder history with it.
  /// Those rows can never be refetched, which is exactly why they cannot
  /// stay: they belong to the account that just left, and the next one must
  /// not inherit its saves.
  Future<Either<Failure, void>> clearForSignOut();

  /// Drops the mirror and refetches from scratch. Development only — used
  /// when switching demo scenarios, where a normal sync would refuse to
  /// overwrite days it has already sealed.
  Future<Either<Failure, DataFreshness>> resetAndSync();

  /// Drops the mirror when it was written by a different build.
  ///
  /// Returns true when a reset happened. Call before the first read.
  Future<bool> resetIfBuildChanged();
}
