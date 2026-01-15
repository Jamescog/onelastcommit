import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_data_source.dart';
import '../models/app_settings_model.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDataSource localDataSource;

  SettingsRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, AppSettings>> getSettings() async {
    try {
      final settings = await localDataSource.getSettings();
      return Right(settings);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, void>> saveSettings(AppSettings settings) async {
    try {
      final model = AppSettingsModel(
        username: settings.username,
        githubToken: settings.githubToken,
        timezone: settings.timezone,
        remindersEnabled: settings.remindersEnabled,
        reminderTimes: settings.reminderTimes,
        trackWeekends: settings.trackWeekends,
        installedAt: settings.installedAt,
      );
      await localDataSource.saveSettings(model);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, void>> markInstalled() async {
    try {
      final settings = await localDataSource.getSettings();
      if (settings.installedAt == null) {
        final newSettings = AppSettingsModel(
          username: settings.username,
          githubToken: settings.githubToken,
          timezone: settings.timezone,
          remindersEnabled: settings.remindersEnabled,
          reminderTimes: settings.reminderTimes,
          trackWeekends: settings.trackWeekends,
          installedAt: DateTime.now(),
        );
        await localDataSource.saveSettings(newSettings);
      }
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure());
    }
  }
}
