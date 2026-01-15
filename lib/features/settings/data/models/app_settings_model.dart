import '../../domain/entities/app_settings.dart';

class AppSettingsModel extends AppSettings {
  const AppSettingsModel({
    required super.username,
    super.githubToken,
    required super.timezone,
    required super.remindersEnabled,
    required super.reminderTimes,
    required super.trackWeekends,
    super.installedAt,
  });

  factory AppSettingsModel.fromMap(Map<String, String> map) {
    return AppSettingsModel(
      username: map['username'] ?? '',
      githubToken: map['github_token'] ?? '',
      timezone: map['timezone'] ?? 'UTC',
      remindersEnabled: map['reminders_enabled'] == 'true',
      reminderTimes: map['reminder_times']?.split(',') ?? [],
      trackWeekends: map['weekend_mode'] == 'true',
      installedAt: map['installed_at'] != null
          ? DateTime.parse(map['installed_at']!)
          : null,
    );
  }

  Map<String, String> toMap() {
    return {
      'username': username,
      'github_token': githubToken,
      'timezone': timezone,
      'reminders_enabled': remindersEnabled.toString(),
      'reminder_times': reminderTimes.join(','),
      'weekend_mode': trackWeekends.toString(),
      if (installedAt != null)
        'installed_at': installedAt!.toUtc().toIso8601String(),
    };
  }
}
