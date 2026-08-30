import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/app_settings.dart';

abstract class SettingsLocalDataSource {
  Future<AppSettings> getSettings();
  Future<void> saveSettings(AppSettings settings);
}

class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  final SharedPreferences sharedPreferences;

  SettingsLocalDataSourceImpl({required this.sharedPreferences});

  /// Reads what is stored, tolerating what is not.
  ///
  /// `byName` and `DateTime.parse` both throw on anything they do not
  /// recognise, and this read gates the whole app — one unparseable string
  /// left it holding on the splash screen forever, with no retry and no way
  /// out but a reinstall. A preference nobody can parse is a preference
  /// nobody set.
  @override
  Future<AppSettings> getSettings() async {
    final rawInstalled = sharedPreferences.getString('installed_at');
    return AppSettings(
      username: sharedPreferences.getString('username') ?? '',
      timezone: sharedPreferences.getString('timezone') ?? 'UTC',
      remindersEnabled: sharedPreferences.getBool('reminders_enabled') ?? true,
      reminderTimes:
          sharedPreferences.getStringList('reminder_times') ?? ['20:00'],
      trackWeekends: sharedPreferences.getBool('weekend_mode') ?? true,
      themeMode:
          ThemeMode.values.asNameMap()[sharedPreferences.getString(
            'theme_mode',
          )] ??
          ThemeMode.system,
      installedAt: rawInstalled == null
          ? null
          : DateTime.tryParse(rawInstalled),
    );
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await sharedPreferences.setString('username', settings.username);
    // Removed rather than written. Older builds stored the GitHub token here
    // in plain text before secure storage existed, and the field outlived its
    // last writer as an always-empty string — one refactor away from becoming
    // a plaintext token store again.
    await sharedPreferences.remove('github_token');
    await sharedPreferences.setString('timezone', settings.timezone);
    await sharedPreferences.setBool(
      'reminders_enabled',
      settings.remindersEnabled,
    );
    await sharedPreferences.setStringList(
      'reminder_times',
      settings.reminderTimes,
    );
    await sharedPreferences.setBool('weekend_mode', settings.trackWeekends);
    await sharedPreferences.setString('theme_mode', settings.themeMode.name);
    if (settings.installedAt != null) {
      await sharedPreferences.setString(
        'installed_at',
        settings.installedAt!.toUtc().toIso8601String(),
      );
    } else {
      await sharedPreferences.remove('installed_at');
    }
  }
}
