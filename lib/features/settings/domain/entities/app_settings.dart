import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class AppSettings extends Equatable {
  const AppSettings({
    required this.username,
    required this.timezone,
    required this.remindersEnabled,
    required this.reminderTimes,
    required this.trackWeekends,
    this.githubToken = '',
    this.themeMode = ThemeMode.system,
    this.installedAt,
  });

  final String username;

  /// Phase 2 moves this to secure storage. It is never sent to the OLC server.
  final String githubToken;

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

  AppSettings copyWith({
    String? username,
    String? githubToken,
    String? timezone,
    bool? remindersEnabled,
    List<String>? reminderTimes,
    bool? trackWeekends,
    ThemeMode? themeMode,
    DateTime? installedAt,
  }) => AppSettings(
    username: username ?? this.username,
    githubToken: githubToken ?? this.githubToken,
    timezone: timezone ?? this.timezone,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    reminderTimes: reminderTimes ?? this.reminderTimes,
    trackWeekends: trackWeekends ?? this.trackWeekends,
    themeMode: themeMode ?? this.themeMode,
    installedAt: installedAt ?? this.installedAt,
  );

  @override
  List<Object?> get props => [
    username,
    githubToken,
    timezone,
    remindersEnabled,
    reminderTimes,
    trackWeekends,
    themeMode,
    installedAt,
  ];
}
