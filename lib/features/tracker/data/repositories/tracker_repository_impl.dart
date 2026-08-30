import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/util/build_identity.dart';
import '../../../../core/util/notification_service.dart';
import '../../../settings/data/datasources/settings_local_data_source.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/tracker_repository.dart';
import '../../domain/services/reminder_journal.dart';
import '../../domain/services/streak_calculator.dart';
import '../datasources/tracker_data_source.dart';
import '../datasources/tracker_local_data_source.dart';

/// Local-first. Every read hits the mirror and returns immediately; [sync] is
/// the only thing that talks to the remote source, and no screen waits on it.
///
/// This is what makes offline work without an offline mode — both paths are
/// the same path, and the difference shows up as [DataFreshness] rather than
/// as a different code branch.
class TrackerRepositoryImpl implements TrackerRepository {
  const TrackerRepositoryImpl({
    required this.remote,
    required this.local,
    required this.settings,
    required this.notifications,
  });

  final TrackerDataSource remote;
  final TrackerLocalDataSource local;

  /// Consulted for one thing only: whether Android is actually showing our
  /// reminders. A history row saying we nagged someone is a lie when the
  /// permission was withheld, and it would go on to claim credit for saves
  /// that no notification caused.
  final NotificationService notifications;

  /// Only for `installedAt`, which anchors the OLC era on the analysis
  /// page. It never gates whether a contribution counts toward the streak —
  /// that was the original bug. See PLAN.md section 4.
  final SettingsLocalDataSource settings;

  /// A mirror older than this is worth flagging to the user. It does not stop
  /// the data being shown — it stops the app claiming certainty about it.
  static const staleAfter = Duration(hours: 6);

  @override
  Future<Either<Failure, GitHubProfile>> getProfile() async {
    try {
      final profile = await local.getProfile();
      if (profile == null) return Left(CacheFailure());
      return Right(profile);
    } catch (_) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, List<ContributionDay>>> getCalendar({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      return Right(await local.getCalendar(from: from, to: to));
    } catch (_) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, List<ContributionActivity>>> getActivity({
    int limit = 20,
  }) async {
    try {
      return Right(await local.getActivity(limit: limit));
    } catch (_) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, List<RepoContribution>>> getRepos() async {
    try {
      return Right(await local.getRepos());
    } catch (_) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, StreakStatus>> getStreak() async {
    try {
      final days = await local.getCalendar();
      final streak = StreakCalculator.streakFrom(
        days,
        now: DateTime.now(),
        freshness: await currentFreshness(),
      );
      if (streak == null) return Left(CacheFailure());
      return Right(streak);
    } catch (_) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, OlcInsights>> getInsights() async {
    try {
      final saved = await settings.getSettings();
      return Right(
        StreakCalculator.insightsFrom(
          days: await local.getCalendar(),
          reminders: await local.getReminders(),
          activity: await local.getActivity(limit: 500),
          installedAt: saved.installedAt ?? DateTime.now(),
        ),
      );
    } catch (_) {
      return Left(CacheFailure());
    }
  }

  /// Reminder history, recorded and settled.
  ///
  /// Two passes over the same local data. The first reconstructs firings the
  /// OS delivered while the app was not running — nothing reports those, so
  /// they are derived from the schedule and the high-water mark below. The
  /// second asks the calendar what became of every reminder still open,
  /// including the ones just written, because a nag from last night is
  /// usually answerable by the time the app is next opened.
  @override
  Future<Either<Failure, ReminderCheck>> recordReminderOutcomes() async {
    try {
      final now = DateTime.now().toUtc();
      final since = await local.getLastReminderCheckAt();

      // First run. We cannot claim reminders fired before we started
      // watching for them, so this only starts the clock.
      if (since == null) {
        await local.setLastReminderCheckAt(now);
        return const Right(ReminderCheck());
      }

      final saved = await settings.getSettings();
      final days = await local.getCalendar();
      final open = await local.getReminders();

      final recorded = <ReminderEvent>[];
      if (saved.remindersEnabled && await _notificationsAllowed()) {
        final known = open.map((e) => e.id).toSet();
        for (final at in ReminderJournal.firingsBetween(
          times: saved.reminderTimes,
          timezone: saved.timezone,
          includeWeekends: saved.trackWeekends,
          after: since,
          until: now,
        )) {
          if (!known.add(ReminderJournal.idFor(at))) continue;
          recorded.add(ReminderJournal.record(sentAt: at, days: days));
        }
      }

      final syncedAt = await local.getLastSyncedAt();
      final resolved = <ReminderEvent>[];
      for (final event in [...open, ...recorded]) {
        final settled = ReminderJournal.resolve(
          event,
          days: days,
          now: now,
          syncedAt: syncedAt,
        );
        if (settled != null) resolved.add(settled);
      }

      // Recorded first, resolved second: a firing that was answered in the
      // same pass appears in both lists, and the write replaces on id, so
      // the settled version has to land last.
      await local.saveReminders([...recorded, ...resolved]);
      await local.setLastReminderCheckAt(now);

      return Right(ReminderCheck(recorded: recorded, resolved: resolved));
    } catch (_) {
      return Left(CacheFailure());
    }
  }

  /// Whether the OS would have shown a reminder scheduled for this window.
  ///
  /// Off-device there is no plugin to ask; assuming allowed there keeps tests
  /// and the desktop build recording rather than silently doing nothing.
  Future<bool> _notificationsAllowed() async {
    try {
      return (await notifications.permissions()).notificationsAllowed;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<Either<Failure, DataFreshness>> sync() async {
    try {
      final days = await remote.getCalendar();
      final activity = await remote.getActivity(limit: 50);
      final repos = await remote.getRepos();
      final reminders = await remote.getReminderHistory();
      final profile = await remote.getProfile();

      await local.saveCalendar(days);
      await local.saveActivity(activity);
      await local.saveRepos(repos);
      await local.saveReminders(reminders);
      await local.saveProfile(profile);

      // Everything before today is now final.
      if (days.isNotEmpty) {
        await local.sealDaysBefore(days.last.date);
      }
      await local.setLastSyncedAt(DateTime.now().toUtc());
      return const Right(DataFreshness.fresh);
    } catch (_) {
      // A failed refresh is not a failed read. The mirror still holds real
      // data; it just cannot be vouched for any more.
      final hasCache = (await _safeDayCount()) > 0;
      return Right(hasCache ? DataFreshness.stale : DataFreshness.error);
    }
  }

  @override
  Future<bool> resetIfBuildChanged() async {
    try {
      final stored = await local.getBuildId();
      if (stored == BuildIdentity.value) return false;

      // Rows written by different parsing code are not worth reasoning about.
      // Cheaper to refetch than to guess which fields are still correct.
      // Reminder history survives: this device wrote it, and no refetch can
      // bring it back.
      await local.clearRemoteMirror();
      await local.setBuildId(BuildIdentity.value);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Either<Failure, void>> clearForSignOut() async {
    try {
      await local.clearAll();
      return const Right(null);
    } catch (_) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, DataFreshness>> resetAndSync() async {
    try {
      await local.clearAll();
      await local.setBuildId(BuildIdentity.value);
    } catch (_) {
      return Left(CacheFailure());
    }
    return sync();
  }

  Future<int> _safeDayCount() async {
    try {
      return (await local.getCalendar()).length;
    } catch (_) {
      return 0;
    }
  }

  /// How much the mirror can be trusted right now, independent of any refresh.
  Future<DataFreshness> currentFreshness() async {
    try {
      final last = await local.getLastSyncedAt();
      if (last == null) return DataFreshness.error;
      final age = DateTime.now().toUtc().difference(last);
      return age > staleAfter ? DataFreshness.stale : DataFreshness.fresh;
    } catch (_) {
      return DataFreshness.error;
    }
  }
}
