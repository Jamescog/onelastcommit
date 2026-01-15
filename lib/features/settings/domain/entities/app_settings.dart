import 'package:equatable/equatable.dart';

class AppSettings extends Equatable {
  final String username;
  final String timezone;
  final bool remindersEnabled;
  final List<String> reminderTimes;
  final bool trackWeekends;
  final DateTime? installedAt;

  const AppSettings({
    required this.username,
    required this.timezone,
    required this.remindersEnabled,
    required this.reminderTimes,
    required this.trackWeekends,
    this.installedAt,
  });

  @override
  List<Object?> get props => [
    username,
    timezone,
    remindersEnabled,
    reminderTimes,
    trackWeekends,
    installedAt,
  ];
}
