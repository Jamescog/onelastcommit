import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/util/reminder_scheduler.dart';
import '../../../onboarding/domain/repositories/auth_repository.dart';
import '../../../tracker/domain/repositories/tracker_repository.dart';
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

/// Leave the account. Everything tied to it goes with it.
class SignOut extends SettingsEvent {}

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

  /// Sign-out is the one thing settings owns that reaches outside itself: the
  /// token, the alarms and the history all have to go together, and this is
  /// where the state the router reads is emitted from, so this is where the
  /// four are sequenced.
  final AuthRepository auth;
  final TrackerRepository tracker;

  SettingsBloc({
    required this.repository,
    required this.scheduler,
    required this.auth,
    required this.tracker,
  }) : super(SettingsInitial()) {
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

    on<SignOut>((event, emit) async {
      // Alarms first. Everything after this deletes the data a reminder
      // would be about, and a nag that fires in the gap would be reasoning
      // from a mirror that is already half gone.
      await scheduler.cancelAll();
      await auth.signOut();
      await tracker.clearForSignOut();

      // Emitted last, because the router watches this bloc: the moment the
      // username is empty the redirect sends the app back to onboarding. No
      // screen navigates by hand.
      final cleared = await repository.clearAccount();
      cleared.fold((_) => add(LoadSettings()), (s) => emit(SettingsLoaded(s)));
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
