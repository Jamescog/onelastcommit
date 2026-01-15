import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
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

  SettingsBloc({required this.repository}) : super(SettingsInitial()) {
    on<LoadSettings>((event, emit) async {
      emit(SettingsLoading());
      final result = await repository.getSettings();
      result.fold(
        (failure) => null,
        (settings) => emit(SettingsLoaded(settings)),
      );
    });

    on<UpdateSettings>((event, emit) async {
      await repository.saveSettings(event.settings);
      emit(SettingsLoaded(event.settings));
    });
  }
}
