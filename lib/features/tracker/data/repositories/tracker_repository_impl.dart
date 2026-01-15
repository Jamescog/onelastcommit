import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/commit_event.dart';
import '../../domain/repositories/tracker_repository.dart';
import '../datasources/tracker_local_data_source.dart';
import '../datasources/tracker_remote_data_source.dart';
import '../../../settings/data/datasources/settings_local_data_source.dart';

class TrackerRepositoryImpl implements TrackerRepository {
  final TrackerRemoteDataSource remoteDataSource;
  final TrackerLocalDataSource localDataSource;
  final SettingsLocalDataSource settingsLocalDataSource;

  TrackerRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.settingsLocalDataSource,
  });

  @override
  Future<Either<Failure, List<CommitEvent>>> getCommitHistory() async {
    try {
      final localEvents = await localDataSource.getLastEvents();
      return Right(localEvents);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, void>> refreshCommits() async {
    try {
      final settings = await settingsLocalDataSource.getSettings();
      if (settings.username.isEmpty) return const Right(null);

      final lastFetched = await localDataSource.getLastFetchedAt();
      final now = DateTime.now();

      if (lastFetched != null && now.difference(lastFetched).inHours < 3) {
        return const Right(null);
      }

      final etag = await localDataSource.getEtag();
      final remoteEvents = await remoteDataSource.getPushEvents(
        settings.username,
        etag: etag,
        token: settings.githubToken,
      );

      if (remoteEvents.isNotEmpty) {
        await localDataSource.cacheEvents(remoteEvents);
        final newEtag = remoteDataSource.lastEtag;
        if (newEtag != null) {
          await localDataSource.saveEtag(newEtag);
        }
      }

      await localDataSource.saveLastFetchedAt(now);
      return const Right(null);
    } on ServerException {
      return Left(ServerFailure());
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, bool>> hasActivityToday() async {
    try {
      final settings = await settingsLocalDataSource.getSettings();
      final now = DateTime.now();

      if (!settings.trackWeekends &&
          (now.weekday == DateTime.saturday ||
              now.weekday == DateTime.sunday)) {
        return const Right(true);
      }

      final events = await localDataSource.getLastEvents();
      final todayStr = now.toIso8601String().substring(0, 10);

      final hasActivity = events.any((e) {
        final sameDay =
            e.occurredAt.toLocal().toIso8601String().substring(0, 10) ==
            todayStr;
        final afterInstall =
            settings.installedAt == null ||
            e.occurredAt.isAfter(settings.installedAt!);
        return sameDay && afterInstall;
      });

      return Right(hasActivity);
    } catch (e) {
      return Left(CacheFailure());
    }
  }
}
