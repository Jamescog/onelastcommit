import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/entities.dart';

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

  /// Refresh the mirror. Returns the freshness that resulted, so a caller can
  /// tell a successful refresh from a silent fall back to cache.
  Future<Either<Failure, DataFreshness>> sync();
}
