import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/util/reminder_scheduler.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

abstract class SettingsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadSettings extends SettingsEvent {}

class UpdateSettings extends SettingsEvent {
  final AppSettings settings;
  UpdateSettings(this.settings);
  @override
  List<Object?> get props => [settings];
}

/// Re-register reminders without any setting having changed — for when the
/// world around them changed instead, e.g. the exact-alarm permission was
/// granted and the schedules should be upgraded from inexact delivery.
class ReapplyReminders extends SettingsEvent {}

abstract class SettingsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {}

class SettingsLoading extends SettingsState {}

class SettingsLoaded extends SettingsState {
  final AppSettings settings;
  SettingsLoaded(this.settings);
  @override
  List<Object?> get props => [settings];
}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsRepository repository;
  final ReminderScheduler scheduler;

  SettingsBloc({required this.repository, required this.scheduler})
    : super(SettingsInitial()) {
    on<LoadSettings>((event, emit) async {
      emit(SettingsLoading());
      final result = await repository.getSettings();
      final settings = result.fold((failure) => null, (s) => s);
      if (settings == null) return;
      emit(SettingsLoaded(settings));
      // Re-asserted on every load: scheduling is idempotent, and permissions
      // may have changed since the schedules were last written.
      await _reschedule(settings);
    });

    on<UpdateSettings>((event, emit) async {
      final previous = state;
      await repository.saveSettings(event.settings);
      emit(SettingsLoaded(event.settings));
      // Theme and account edits should not churn the OS alarm table.
      if (previous is SettingsLoaded &&
          !_affectsSchedule(previous.settings, event.settings)) {
        return;
      }
      await _reschedule(event.settings);
    });

    on<ReapplyReminders>((event, emit) async {
      final current = state;
      if (current is SettingsLoaded) await _reschedule(current.settings);
    });
  }

  static bool _affectsSchedule(AppSettings a, AppSettings b) =>
      a.remindersEnabled != b.remindersEnabled ||
      a.trackWeekends != b.trackWeekends ||
      a.timezone != b.timezone ||
      !listEquals(a.reminderTimes, b.reminderTimes);

  Future<void> _reschedule(AppSettings settings) => scheduler.apply(
    enabled: settings.remindersEnabled,
    times: settings.reminderTimes,
    timezone: settings.timezone,
    includeWeekends: settings.trackWeekends,
  );
}
