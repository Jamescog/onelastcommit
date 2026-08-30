import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olc/core/error/failures.dart';
import 'package:olc/core/theme/app_theme.dart';
import 'package:olc/core/util/notification_service.dart';
import 'package:olc/core/util/reminder_scheduler.dart';
import 'package:olc/core/widgets/widgets.dart';
import 'package:olc/features/onboarding/domain/entities/device_code.dart';
import 'package:olc/features/onboarding/domain/repositories/auth_repository.dart';
import 'package:olc/features/onboarding/presentation/bloc/auth_bloc.dart';
import 'package:olc/features/onboarding/presentation/pages/login_page.dart';
import 'package:olc/features/settings/domain/entities/app_settings.dart';
import 'package:olc/features/settings/domain/repositories/settings_repository.dart';
import 'package:olc/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:olc/features/settings/presentation/pages/settings_page.dart';
import 'package:olc/features/tracker/data/datasources/fake_tracker_data_source.dart';
import 'package:olc/features/tracker/domain/entities/entities.dart';
import 'package:olc/features/tracker/domain/repositories/tracker_repository.dart';
import 'package:olc/features/tracker/domain/services/reminder_journal.dart';
import 'package:olc/features/tracker/domain/services/streak_calculator.dart';
import 'package:olc/features/tracker/presentation/bloc/tracker_bloc.dart';
import 'package:olc/features/tracker/presentation/pages/analysis_page.dart';
import 'package:olc/features/tracker/presentation/pages/tabs/repos_tab.dart';
import 'package:olc/features/tracker/presentation/pages/tabs/stats_tab.dart';
import 'package:olc/features/tracker/presentation/pages/tabs/today_tab.dart';
import 'package:olc/injection_container.dart';

/// Does every screen actually lay out?
///
/// Added after a release build shipped with blank bodies on every screen:
/// AppCard used a Row with CrossAxisAlignment.stretch, which needs a bounded
/// height and never has one inside a ListView. It threw during layout, which
/// renders as a red box in debug and as nothing at all in release.
///
/// `flutter analyze` and `flutter build` both passed throughout — neither
/// executes a layout, so neither could have caught it. This does.
void main() {
  final source = FakeTrackerDataSource();

  setUpAll(() {
    // Settings asks the platform what notifications are actually permitted.
    // Off-device the plugin resolves to null and reports everything allowed,
    // which is all this needs — the point is that the lookup does not throw.
    if (!sl.isRegistered<NotificationService>()) {
      sl.registerLazySingleton(NotificationService.new);
    }
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double textScale = 1,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<TrackerBloc>(
            create: (_) =>
                TrackerBloc(repository: _StubTracker(source))
                  ..add(const LoadTracker()),
          ),
          BlocProvider<SettingsBloc>(
            create: (_) => SettingsBloc(
              repository: _StubSettings(),
              scheduler: _StubScheduler(),
              auth: _StubAuth(),
              tracker: _StubTracker(source),
            )..add(LoadSettings()),
          ),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.dark,
          builder: (context, widget) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: widget!,
          ),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  }

  group('screens lay out without throwing', () {
    testWidgets('Today', (t) => pump(t, const TodayTab()));
    testWidgets('Stats', (t) => pump(t, const StatsTab()));
    testWidgets('Repos', (t) => pump(t, const ReposTab()));
    testWidgets('Analysis', (t) => pump(t, const AnalysisPage()));
    testWidgets('Settings', (t) => pump(t, const SettingsPage()));
  });

  group('screens lay out in light as well as dark', () {
    testWidgets(
      'Today',
      (t) => pump(t, const TodayTab(), theme: AppTheme.light),
    );
    testWidgets(
      'Stats',
      (t) => pump(t, const StatsTab(), theme: AppTheme.light),
    );
    testWidgets(
      'Settings',
      (t) => pump(t, const SettingsPage(), theme: AppTheme.light),
    );
  });

  group('screens survive a doubled text scale', () {
    // A hard overflow throws during layout, which is exactly what pump()
    // asserts against. Nothing in the app reads MediaQuery.textScaler, so
    // every fixed height and unconstrained Row is a candidate.
    testWidgets('Today', (t) => pump(t, const TodayTab(), textScale: 2));
    testWidgets('Stats', (t) => pump(t, const StatsTab(), textScale: 2));
    testWidgets('Repos', (t) => pump(t, const ReposTab(), textScale: 2));
    testWidgets('Analysis', (t) => pump(t, const AnalysisPage(), textScale: 2));
    testWidgets('Settings', (t) => pump(t, const SettingsPage(), textScale: 2));
  });

  testWidgets('the device-code screen lays out', (tester) async {
    // Never pumpAndSettle here: the screen holds a spinner and a one-second
    // countdown, so it is never quiet.
    final auth = AuthBloc(repository: _StubAuth())
      ..add(const StartDeviceFlow());
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: auth),
          BlocProvider<SettingsBloc>(
            create: (_) => SettingsBloc(
              repository: _StubSettings(),
              scheduler: _StubScheduler(),
              auth: _StubAuth(),
              tracker: _StubTracker(source),
            )..add(LoadSettings()),
          ),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const LoginPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('WXYZ-1234'), findsOneWidget);
  });

  group('AppCard survives an unbounded height', () {
    // The exact shape that broke: a card inside a scrollable, where the
    // vertical constraint is infinite.
    testWidgets('plain, toned, and accent-edged, in a ListView', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ListView(
              children: const [
                AppCard(child: Text('plain')),
                AppCard(tone: AppTone.danger, child: Text('toned')),
                AppCard(
                  tone: AppTone.accent,
                  accentEdge: true,
                  child: Text('edged'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('edged'), findsOneWidget);
    });
  });
}

class _StubTracker implements TrackerRepository {
  _StubTracker(this.source);

  final FakeTrackerDataSource source;

  @override
  Future<Either<Failure, GitHubProfile>> getProfile() async =>
      Right(await source.getProfile());

  @override
  Future<Either<Failure, List<ContributionDay>>> getCalendar({
    DateTime? from,
    DateTime? to,
  }) async => Right(await source.getCalendar());

  @override
  Future<Either<Failure, List<ContributionActivity>>> getActivity({
    int limit = 20,
  }) async => Right(await source.getActivity(limit: limit));

  @override
  Future<Either<Failure, List<RepoContribution>>> getRepos() async =>
      Right(await source.getRepos());

  @override
  Future<Either<Failure, StreakStatus>> getStreak() async {
    final streak = StreakCalculator.streakFrom(
      await source.getCalendar(),
      now: DateTime.now(),
    );
    return streak == null ? Left(CacheFailure()) : Right(streak);
  }

  @override
  Future<Either<Failure, OlcInsights>> getInsights() async => Right(
    StreakCalculator.insightsFrom(
      days: await source.getCalendar(),
      reminders: await source.getReminderHistory(),
      activity: await source.getActivity(limit: 100),
      installedAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
  );

  @override
  Future<Either<Failure, ReminderCheck>> recordReminderOutcomes() async =>
      const Right(ReminderCheck());

  @override
  Future<Either<Failure, DataFreshness>> sync() async =>
      const Right(DataFreshness.fresh);

  @override
  Future<Either<Failure, void>> clearForSignOut() async => const Right(null);

  @override
  Future<Either<Failure, DataFreshness>> resetAndSync() async =>
      const Right(DataFreshness.fresh);

  @override
  Future<bool> resetIfBuildChanged() async => false;
}

/// Loading settings re-asserts the reminder schedule, which off-device would
/// hit the notifications method channel and throw. Scheduling is not what
/// these tests exercise.
class _StubScheduler extends ReminderScheduler {
  _StubScheduler() : super(notifications: NotificationService());

  @override
  Future<ScheduleOutcome> apply({
    required bool enabled,
    required List<String> times,
    required String timezone,
    required bool includeWeekends,
  }) async => ScheduleOutcome(scheduled: times, dropped: const []);
}

class _StubSettings implements SettingsRepository {
  @override
  Future<Either<Failure, AppSettings>> getSettings() async => Right(
    AppSettings(
      username: 'jamescog',
      timezone: 'UTC',
      remindersEnabled: true,
      reminderTimes: const ['20:00'],
      trackWeekends: true,
      installedAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
  );

  @override
  Future<Either<Failure, void>> saveSettings(AppSettings settings) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> markInstalled() async => const Right(null);

  @override
  Future<Either<Failure, AppSettings>> clearAccount() async => const Right(
    AppSettings(
      username: '',
      timezone: 'UTC',
      remindersEnabled: false,
      reminderTimes: [],
      trackWeekends: true,
    ),
  );
}

/// A device flow that hands out a code and then waits forever, which is the
/// state the screen spends its whole life in.
class _StubAuth implements AuthRepository {
  @override
  Future<Either<Failure, DeviceCodeGrant>> requestDeviceCode() async => Right(
    DeviceCodeGrant(
      userCode: 'WXYZ-1234',
      verificationUri: 'https://github.com/login/device',
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      interval: 5,
      deviceCode: 'device',
    ),
  );

  /// Never answers. Returning [AuthPending] would leave the bloc's backoff
  /// timer pending past the end of the test, which the binding fails on — and
  /// closing the bloc to drain it deadlocks, because the fake clock only moves
  /// when the tester pumps. An unfinished future is not a timer.
  @override
  Future<AuthPoll> pollForToken(DeviceCodeGrant grant) =>
      Completer<AuthPoll>().future;

  @override
  Future<bool> refreshIfNeeded({bool force = false}) async => true;

  @override
  Future<void> signOut() async {}
}
