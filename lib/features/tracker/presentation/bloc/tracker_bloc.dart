import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/entities.dart';
import '../../domain/repositories/tracker_repository.dart';

abstract class TrackerEvent extends Equatable {
  const TrackerEvent();

  @override
  List<Object?> get props => [];
}

/// Read the local mirror. Never touches the network.
class LoadTracker extends TrackerEvent {
  const LoadTracker();
}

/// Refresh the mirror, then reload. Pull-to-refresh.
class SyncTracker extends TrackerEvent {
  const SyncTracker();
}

abstract class TrackerState extends Equatable {
  const TrackerState();

  @override
  List<Object?> get props => [];
}

class TrackerInitial extends TrackerState {
  const TrackerInitial();
}

class TrackerLoading extends TrackerState {
  const TrackerLoading();
}

class TrackerLoaded extends TrackerState {
  const TrackerLoaded({
    required this.streak,
    this.activity = const [],
    this.calendar = const [],
  });

  final StreakStatus streak;
  final List<ContributionActivity> activity;
  final List<ContributionDay> calendar;

  @override
  List<Object?> get props => [streak, activity, calendar];
}

class TrackerFailed extends TrackerState {
  const TrackerFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Minimal wiring against the new repository. The full state machine —
/// empty, stale-with-cache, and the local streak computation — lands in
/// commit 7; nothing renders from this bloc until commit 9.
class TrackerBloc extends Bloc<TrackerEvent, TrackerState> {
  TrackerBloc({required this.repository}) : super(const TrackerInitial()) {
    on<LoadTracker>(_onLoad);
    on<SyncTracker>(_onSync);
  }

  final TrackerRepository repository;

  Future<void> _onLoad(LoadTracker event, Emitter<TrackerState> emit) async {
    emit(const TrackerLoading());
    final result = await repository.getStreak();
    result.fold(
      (_) => emit(const TrackerFailed('Could not read your streak')),
      (streak) => emit(TrackerLoaded(streak: streak)),
    );
  }

  Future<void> _onSync(SyncTracker event, Emitter<TrackerState> emit) async {
    await repository.sync();
    add(const LoadTracker());
  }
}
