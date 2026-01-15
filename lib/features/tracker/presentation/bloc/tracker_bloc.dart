import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/commit_event.dart';
import '../../domain/repositories/tracker_repository.dart';

abstract class TrackerEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class FetchTrackerData extends TrackerEvent {}

class RefreshTrackerData extends TrackerEvent {}

abstract class TrackerState extends Equatable {
  @override
  List<Object?> get props => [];
}

class TrackerInitial extends TrackerState {}

class TrackerLoading extends TrackerState {}

class TrackerLoaded extends TrackerState {
  final List<CommitEvent> events;
  final bool hasActivityToday;
  TrackerLoaded({required this.events, required this.hasActivityToday});
  @override
  List<Object?> get props => [events, hasActivityToday];
}

class TrackerError extends TrackerState {
  final String message;
  TrackerError(this.message);
  @override
  List<Object?> get props => [message];
}

class TrackerBloc extends Bloc<TrackerEvent, TrackerState> {
  final TrackerRepository repository;

  TrackerBloc({required this.repository}) : super(TrackerInitial()) {
    on<FetchTrackerData>((event, emit) async {
      emit(TrackerLoading());
      final historyResult = await repository.getCommitHistory();
      final activityResult = await repository.hasActivityToday();

      historyResult.fold(
        (failure) => emit(TrackerError('Failed to load history')),
        (events) => activityResult.fold(
          (failure) => emit(TrackerError('Failed to check activity')),
          (hasActivity) => emit(
            TrackerLoaded(events: events, hasActivityToday: hasActivity),
          ),
        ),
      );
    });

    on<RefreshTrackerData>((event, emit) async {
      await repository.refreshCommits();
      add(FetchTrackerData());
    });
  }
}
