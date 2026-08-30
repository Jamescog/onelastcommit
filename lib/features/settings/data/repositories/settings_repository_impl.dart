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
      await localDataSource.saveSettings(_toModel(settings));
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
        await localDataSource.saveSettings(
          _toModel(settings.copyWith(installedAt: DateTime.now())),
        );
      }
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, AppSettings>> clearAccount() async {
    try {
      final current = await localDataSource.getSettings();
      // Not copyWith: installedAt has to become null, and copyWith cannot
      // express that. The analysis era ends with the account it measured.
      final cleared = AppSettings(
        username: '',
        githubToken: '',
        timezone: current.timezone,
        remindersEnabled: false,
        reminderTimes: current.reminderTimes,
        trackWeekends: current.trackWeekends,
        themeMode: current.themeMode,
      );
      await localDataSource.saveSettings(_toModel(cleared));
      return Right(cleared);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  static AppSettingsModel _toModel(AppSettings s) => AppSettingsModel(
    username: s.username,
    githubToken: s.githubToken,
    timezone: s.timezone,
    remindersEnabled: s.remindersEnabled,
    reminderTimes: s.reminderTimes,
    trackWeekends: s.trackWeekends,
    themeMode: s.themeMode,
    installedAt: s.installedAt,
  );
}
