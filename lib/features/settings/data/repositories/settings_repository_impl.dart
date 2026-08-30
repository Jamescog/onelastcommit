import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_data_source.dart';

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
      await localDataSource.saveSettings(settings);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, AppSettings>> clearAccount() async {
    try {
      final current = await localDataSource.getSettings();
      // The analysis era ends with the account it measured, so installedAt
      // has to go back to null.
      final cleared = current.copyWith(
        username: '',
        remindersEnabled: false,
        clearInstalledAt: true,
      );
      await localDataSource.saveSettings(cleared);
      return Right(cleared);
    } catch (e) {
      return Left(CacheFailure());
    }
  }
}
