import '../../domain/entities/app_settings.dart';

class AppSettingsModel extends AppSettings {
  const AppSettingsModel({
    required super.username,
    required super.timezone,
    required super.remindersEnabled,
    required super.reminderTimes,
    required super.trackWeekends,
    super.githubToken,
    super.themeMode,
    super.installedAt,
  });
}
