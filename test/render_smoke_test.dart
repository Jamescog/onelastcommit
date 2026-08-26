import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olc/core/error/failures.dart';
import 'package:olc/core/theme/app_theme.dart';
import 'package:olc/core/widgets/widgets.dart';
import 'package:olc/features/settings/domain/entities/app_settings.dart';
import 'package:olc/features/settings/domain/repositories/settings_repository.dart';
import 'package:olc/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:olc/features/settings/presentation/pages/settings_page.dart';
import 'package:olc/features/tracker/data/datasources/fake_tracker_data_source.dart';
import 'package:olc/features/tracker/domain/entities/entities.dart';
import 'package:olc/features/tracker/domain/repositories/tracker_repository.dart';
import 'package:olc/features/tracker/domain/services/streak_calculator.dart';
import 'package:olc/features/tracker/presentation/bloc/tracker_bloc.dart';
import 'package:olc/features/tracker/presentation/pages/analysis_page.dart';
import 'package:olc/features/tracker/presentation/pages/tabs/repos_tab.dart';
import 'package:olc/features/tracker/presentation/pages/tabs/stats_tab.dart';
import 'package:olc/features/tracker/presentation/pages/tabs/today_tab.dart';

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

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<TrackerBloc>(
            create: (_) => TrackerBloc(repository: _StubTracker(source))
              ..add(const LoadTracker()),
          ),
          BlocProvider<SettingsBloc>(
            create: (_) => SettingsBloc(repository: _StubSettings())
              ..add(LoadSettings()),
          ),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: Scaffold(body: child)),
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
  Future<Either<Failure, DataFreshness>> sync() async =>
      const Right(DataFreshness.fresh);

  @override
  Future<Either<Failure, DataFreshness>> resetAndSync() async =>
      const Right(DataFreshness.fresh);
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
}
