import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/app_settings.dart';

abstract class SettingsRepository {
  Future<Either<Failure, AppSettings>> getSettings();
  Future<Either<Failure, void>> saveSettings(AppSettings settings);
  Future<Either<Failure, void>> markInstalled();

  /// Forgets the account, keeping the preferences that describe the phone
  /// rather than the person. Returns what is left, so the caller can show it
  /// without a second read.
  ///
  /// Reminders are switched off as part of this: the schedules are cancelled
  /// at sign-out, but the flag is what `LoadSettings` re-asserts them from on
  /// the next launch, and a signed-out app has nothing to remind anyone
  /// about.
  Future<Either<Failure, AppSettings>> clearAccount();
}
