import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
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

/// Refresh the mirror, then reload. Pull-to-refresh and first run.
class SyncTracker extends TrackerEvent {
  const SyncTracker();
}

/// Record any reminder that has fired and settle the ones still open.
///
/// Local only — no network, so it is cheap enough for every foreground. The
/// mirror it reads is whatever the last sync left behind, and anything it
/// cannot answer yet stays open for the next check.
class CheckReminders extends TrackerEvent {
  const CheckReminders();
}

/// Wipe the mirror and refetch. Development only.
class ResetTracker extends TrackerEvent {
  const ResetTracker();
}

/// Sealed so a new state cannot be added without every screen being made to
/// say what it renders for it. The Today tab's catch-all used to draw an empty
/// box for anything it did not recognise.
sealed class TrackerState extends Equatable {
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

/// Loaded and readable. [streak.freshness] says how much to trust it.
class TrackerLoaded extends TrackerState {
  const TrackerLoaded({
    required this.streak,
    this.activity = const [],
    this.calendar = const [],
    this.repos = const [],
    this.profile,
    this.insights,
    this.isSyncing = false,
  });

  final StreakStatus streak;
  final List<ContributionActivity> activity;
  final List<ContributionDay> calendar;
  final List<RepoContribution> repos;
  final GitHubProfile? profile;

  /// OLC-era aggregates for the analysis page. Null until enough history has
  /// accrued to say anything.
  final OlcInsights? insights;

  /// A refresh is running behind data that is already on screen. The UI shows
  /// a quiet indicator rather than tearing down to a spinner.
  final bool isSyncing;

  TrackerLoaded copyWith({bool? isSyncing}) => TrackerLoaded(
    streak: streak,
    activity: activity,
    calendar: calendar,
    repos: repos,
    profile: profile,
    insights: insights,
    isSyncing: isSyncing ?? this.isSyncing,
  );

  @override
  List<Object?> get props => [
    streak,
    activity,
    calendar,
    repos,
    profile,
    insights,
    isSyncing,
  ];
}

/// Nothing has ever been fetched. A new install, not a failure — and
/// specifically not "you have no contributions today".
class TrackerEmpty extends TrackerState {
  const TrackerEmpty();
}

/// The sign-in is gone and cannot be refreshed. The only failure the user
/// cannot wait out, so it is routed rather than merely displayed.
class TrackerUnauthorized extends TrackerState {
  const TrackerUnauthorized();
}

/// The read itself failed. Distinct from [TrackerEmpty] on purpose: presenting
/// a failure as an empty day would tell someone their streak is safe when it
/// may not be, which is the one direction this app must not fail in.
class TrackerFailure extends TrackerState {
  const TrackerFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class TrackerBloc extends Bloc<TrackerEvent, TrackerState> {
  TrackerBloc({required this.repository}) : super(const TrackerInitial()) {
    on<LoadTracker>(_onLoad);
    on<SyncTracker>(_onSync);
    on<CheckReminders>((event, emit) async {
      await repository.recordReminderOutcomes();
      add(const LoadTracker());
    });
    on<ResetTracker>((event, emit) async {
      emit(const TrackerLoading());
      await repository.resetAndSync();
      add(const LoadTracker());
    });
  }

  final TrackerRepository repository;

  /// What the last refresh attempt hit, if it failed.
  ///
  /// An empty mirror means "new install" only when nothing has just failed
  /// trying to fill it. Without this the app greeted a user who signed in on
  /// a plane with "No history yet — Fetch now", and every tap returned the
  /// same screen without ever saying the word offline.
  Failure? _lastSyncFailure;

  Future<void> _onLoad(LoadTracker event, Emitter<TrackerState> emit) async {
    if (state is! TrackerLoaded) emit(const TrackerLoading());

    // A mirror written by a different build may have been parsed by different
    // code. Drop it rather than serving rows whose correctness is unknown.
    if (await repository.resetIfBuildChanged()) {
      await repository.sync();
    }

    final streakResult = await repository.getStreak();

    await streakResult.fold(
      (failure) async {
        final sync = _lastSyncFailure;
        emit(switch ((failure, sync)) {
          // The sign-in is dead. Nothing else matters until it is replaced.
          (_, AuthFailure()) ||
          (AuthFailure(), _) => const TrackerUnauthorized(),
          // Nothing stored, and the attempt to fill it just failed. Saying
          // "no history yet" here would blame the user for the network.
          (EmptyMirrorFailure(), final Failure f) => TrackerFailure(f.message),
          // Nothing stored, nothing went wrong: a genuine first run.
          (EmptyMirrorFailure(), null) => const TrackerEmpty(),
          _ => TrackerFailure(failure.message),
        });
      },
      (streak) async {
        final activity = await repository.getActivity(limit: 20);
        final calendar = await repository.getCalendar();
        final repos = await repository.getRepos();
        final profile = await repository.getProfile();
        final insights = await repository.getInsights();

        emit(
          TrackerLoaded(
            streak: streak,
            activity: activity.getOrElse(() => const []),
            calendar: calendar.getOrElse(() => const []),
            repos: repos.getOrElse(() => const []),
            profile: profile.fold((_) => null, (p) => p),
            insights: insights.fold((_) => null, (i) => i),
          ),
        );
      },
    );
  }

  Future<void> _onSync(SyncTracker event, Emitter<TrackerState> emit) async {
    final current = state;
    if (current is TrackerLoaded) {
      emit(current.copyWith(isSyncing: true));
    } else {
      emit(const TrackerLoading());
    }

    // Ahead of the fetch, not after it: doing this in _onLoad alone would
    // sync, then discover the build had changed, wipe what it just wrote and
    // sync a second time.
    await repository.resetIfBuildChanged();
    final result = await repository.sync();
    _lastSyncFailure = result.fold((failure) => failure, (_) => null);
    // After the refresh, never before it: last night's reminder is answered
    // by the calendar this sync just fetched.
    await repository.recordReminderOutcomes();
    add(const LoadTracker());
  }
}
