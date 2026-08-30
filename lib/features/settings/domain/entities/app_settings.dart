import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class AppSettings extends Equatable {
  const AppSettings({
    required this.username,
    required this.timezone,
    required this.remindersEnabled,
    required this.reminderTimes,
    required this.trackWeekends,
    this.themeMode = ThemeMode.system,
    this.installedAt,
  });

  final String username;

  /// IANA identifier, e.g. `Africa/Addis_Ababa`. Abbreviations like "EAT" are
  /// not valid identifiers and will not resolve.
  final String timezone;

  final bool remindersEnabled;
  final List<String> reminderTimes;

  /// Whether reminders fire at weekends. The contribution graph does not care
  /// what day it is — this only decides whether the app stays quiet.
  final bool trackWeekends;

  final ThemeMode themeMode;

  /// Anchors the OLC era on the analysis page. It never gates whether a
  /// contribution counts toward the streak.
  final DateTime? installedAt;

  /// [clearInstalledAt] exists because `installedAt ?? this.installedAt`
  /// cannot express "set this back to null", and ending the analysis era is
  /// exactly what sign-out has to do. Two callers were building whole
  /// AppSettings by hand to work around it.
  AppSettings copyWith({
    String? username,
    String? timezone,
    bool? remindersEnabled,
    List<String>? reminderTimes,
    bool? trackWeekends,
    ThemeMode? themeMode,
    DateTime? installedAt,
    bool clearInstalledAt = false,
  }) => AppSettings(
    username: username ?? this.username,
    timezone: timezone ?? this.timezone,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    reminderTimes: reminderTimes ?? this.reminderTimes,
    trackWeekends: trackWeekends ?? this.trackWeekends,
    themeMode: themeMode ?? this.themeMode,
    installedAt: clearInstalledAt ? null : (installedAt ?? this.installedAt),
  );

  @override
  List<Object?> get props => [
    username,
    timezone,
    remindersEnabled,
    reminderTimes,
    trackWeekends,
    themeMode,
    installedAt,
  ];
}
