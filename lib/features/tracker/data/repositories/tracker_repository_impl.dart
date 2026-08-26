import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/tracker_repository.dart';
import '../datasources/tracker_data_source.dart';
import '../datasources/tracker_local_data_source.dart';

/// Local-first. Every read hits the mirror and returns immediately; [sync] is
/// the only thing that talks to the remote source, and no screen waits on it.
///
/// This is what makes offline work without an offline mode — both paths are
/// the same path, and the difference shows up as [DataFreshness] rather than
/// as a different code branch.
class TrackerRepositoryImpl implements TrackerRepository {
  const TrackerRepositoryImpl({required this.remote, required this.local});

  final TrackerDataSource remote;
  final TrackerLocalDataSource local;

  /// A mirror older than this is worth flagging to the user. It does not stop
  /// the data being shown — it stops the app claiming certainty about it.
  static const staleAfter = Duration(hours: 6);

  @override
  Future<Either<Failure, GitHubProfile>> getProfile() async {
    try {
      final profile = await local.getProfile();
      if (profile == null) return Left(CacheFailure());
      return Right(profile);
    } catch (_) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, List<ContributionDay>>> getCalendar({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      return Right(await local.getCalendar(from: from, to: to));
    } catch (_) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, List<ContributionActivity>>> getActivity({
    int limit = 20,
  }) async {
    try {
      return Right(await local.getActivity(limit: limit));
    } catch (_) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, List<RepoContribution>>> getRepos() async {
    try {
      return Right(await local.getRepos());
    } catch (_) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, StreakStatus>> getStreak() =>
      throw UnimplementedError('getStreak lands in commit 7');

  @override
  Future<Either<Failure, OlcInsights>> getInsights() =>
      throw UnimplementedError('getInsights lands in commit 7');

  @override
  Future<Either<Failure, DataFreshness>> sync() async {
    try {
      final days = await remote.getCalendar();
      final activity = await remote.getActivity(limit: 50);
      final repos = await remote.getRepos();
      final reminders = await remote.getReminderHistory();
      final profile = await remote.getProfile();

      await local.saveCalendar(days);
      await local.saveActivity(activity);
      await local.saveRepos(repos);
      await local.saveReminders(reminders);
      await local.saveProfile(profile);

      // Everything before today is now final.
      if (days.isNotEmpty) {
        await local.sealDaysBefore(days.last.date);
      }
      await local.setLastSyncedAt(DateTime.now().toUtc());
      return const Right(DataFreshness.fresh);
    } catch (_) {
      // A failed refresh is not a failed read. The mirror still holds real
      // data; it just cannot be vouched for any more.
      final hasCache = (await _safeDayCount()) > 0;
      return Right(hasCache ? DataFreshness.stale : DataFreshness.error);
    }
  }

  Future<int> _safeDayCount() async {
    try {
      return (await local.getCalendar()).length;
    } catch (_) {
      return 0;
    }
  }

  /// How much the mirror can be trusted right now, independent of any refresh.
  Future<DataFreshness> currentFreshness() async {
    try {
      final last = await local.getLastSyncedAt();
      if (last == null) return DataFreshness.error;
      final age = DateTime.now().toUtc().difference(last);
      return age > staleAfter ? DataFreshness.stale : DataFreshness.fresh;
    } catch (_) {
      return DataFreshness.error;
    }
  }
}
