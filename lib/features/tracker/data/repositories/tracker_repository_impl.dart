import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/tracker_repository.dart';

/// Placeholder implementation.
///
/// The real one arrives in commit 6, over the local mirror and the fake data
/// source from commit 5. Nothing calls these yet — the screens still render
/// from mock data until commit 9.
class TrackerRepositoryImpl implements TrackerRepository {
  const TrackerRepositoryImpl();

  @override
  Future<Either<Failure, GitHubProfile>> getProfile() =>
      throw UnimplementedError('getProfile lands in commit 6');

  @override
  Future<Either<Failure, StreakStatus>> getStreak() =>
      throw UnimplementedError('getStreak lands in commit 6');

  @override
  Future<Either<Failure, List<ContributionDay>>> getCalendar({
    DateTime? from,
    DateTime? to,
  }) => throw UnimplementedError('getCalendar lands in commit 6');

  @override
  Future<Either<Failure, List<ContributionActivity>>> getActivity({
    int limit = 20,
  }) => throw UnimplementedError('getActivity lands in commit 6');

  @override
  Future<Either<Failure, List<RepoContribution>>> getRepos() =>
      throw UnimplementedError('getRepos lands in commit 6');

  @override
  Future<Either<Failure, OlcInsights>> getInsights() =>
      throw UnimplementedError('getInsights lands in commit 6');

  @override
  Future<Either<Failure, DataFreshness>> sync() =>
      throw UnimplementedError('sync lands in commit 6');
}
