import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings_model.dart';

abstract class SettingsLocalDataSource {
  Future<AppSettingsModel> getSettings();
  Future<void> saveSettings(AppSettingsModel settings);
}

class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  final SharedPreferences sharedPreferences;

  SettingsLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<AppSettingsModel> getSettings() async {
    return AppSettingsModel(
      username: sharedPreferences.getString('username') ?? '',
      timezone: sharedPreferences.getString('timezone') ?? 'UTC',
      remindersEnabled: sharedPreferences.getBool('reminders_enabled') ?? false,
      reminderTimes: sharedPreferences.getStringList('reminder_times') ?? [],
      trackWeekends: sharedPreferences.getBool('weekend_mode') ?? false,
      installedAt: sharedPreferences.getString('installed_at') != null
          ? DateTime.parse(sharedPreferences.getString('installed_at')!)
          : null,
    );
  }

  @override
  Future<void> saveSettings(AppSettingsModel settings) async {
    await sharedPreferences.setString('username', settings.username);
    await sharedPreferences.setString('timezone', settings.timezone);
    await sharedPreferences.setBool('reminders_enabled', settings.remindersEnabled);
    await sharedPreferences.setStringList('reminder_times', settings.reminderTimes);
    await sharedPreferences.setBool('weekend_mode', settings.trackWeekends);
    if (settings.installedAt != null) {
      await sharedPreferences.setString(
        'installed_at',
        settings.installedAt!.toUtc().toIso8601String(),
      );
    }
  }
}
