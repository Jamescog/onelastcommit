import 'package:equatable/equatable.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/util/reminder_scheduler.dart';
import '../../../../core/util/utc_date.dart';
import '../entities/entities.dart';
import 'streak_calculator.dart';

/// What one pass of the reminder check found.
///
/// [saves] is the interesting half: it is the only moment the app can know a
/// nag worked, and Phase 3's background check uses it to decide whether the
/// quiet "streak saved" confirmation is worth showing.
class ReminderCheck extends Equatable {
  const ReminderCheck({this.recorded = const [], this.resolved = const []});

  /// Firings noticed for the first time in this pass.
  final List<ReminderEvent> recorded;

  /// Events that stopped being [ReminderOutcome.unknown] in this pass.
  final List<ReminderEvent> resolved;

  List<ReminderEvent> get saves =>
      resolved.where((e) => e.outcome == ReminderOutcome.saved).toList();

  bool get isEmpty => recorded.isEmpty && resolved.isEmpty;

  @override
  List<Object?> get props => [recorded, resolved];
}

/// Turns scheduled reminders into recorded history.
///
/// Nothing tells this app when one of its reminders was shown. The OS owns
/// the alarm — that is the whole point of the schedule-optimistically design,
/// because code that has to run at 20:30 is the least reliable thing on
/// Android — and `flutter_local_notifications` reports a notification only
/// when it is *tapped*, which most useful reminders never are. So a firing is
/// reconstructed rather than observed: the schedule is deterministic, so the
/// instants it produced between two checks are computable after the fact.
///
/// Everything here is pure. The repository supplies the mirror and the clock;
/// this decides what should be written.
class ReminderJournal {
  const ReminderJournal._();

  /// How far back a single check will reconstruct.
  ///
  /// The alarms repeat daily whether or not the app runs, so a week-old gap
  /// really did produce a week of reminders. Past that the settings they were
  /// scheduled from are no longer evidence of anything — times change, phones
  /// stay off — and these rows are the one part of the database that can
  /// never be refetched. Losing history is recoverable by waiting; inventing
  /// it is not.
  static const backfillLimit = Duration(days: 7);

  /// The instants the schedule fired at, in `(after, until]`.
  ///
  /// Derived from the same times, zone and weekend rule the scheduler
  /// registered with the OS — including its refusal to schedule anything
  /// inside [ReminderScheduler.minRunway] of the deadline — so the journal
  /// reconstructs the set that actually exists rather than a parallel guess
  /// at it.
  static List<DateTime> firingsBetween({
    required List<String> times,
    required String timezone,
    required bool includeWeekends,
    required DateTime after,
    required DateTime until,
  }) {
    if (!until.isAfter(after)) return const [];

    final tz.Location zone;
    try {
      zone = tz.getLocation(timezone);
    } catch (_) {
      // The zone the schedules were written in is unreadable, so there is no
      // way to say when they fired. The timezone card already warns about it.
      return const [];
    }

    final floor = until.subtract(backfillLimit);
    final start = tz.TZDateTime.from(
      after.isAfter(floor) ? after : floor,
      zone,
    );
    final end = tz.TZDateTime.from(until, zone);

    final firings = <DateTime>[];
    for (final time in times) {
      final parts = time.split(':');
      final hour = int.tryParse(parts.first);
      final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
      if (hour == null || minute == null) continue;

      final runway = ReminderScheduler.runwayOf(time, timezone);
      if (runway != null && runway < ReminderScheduler.minRunway) continue;

      // Built from calendar components a day at a time, like the scheduler
      // does, so a DST jump moves the instant and not the wall clock. The
      // extra day either side costs nothing and covers a shift across
      // midnight.
      for (var offset = -1; ; offset++) {
        final at = tz.TZDateTime(
          zone,
          start.year,
          start.month,
          start.day + offset,
          hour,
          minute,
        );
        if (at.isAfter(end)) break;
        if (!at.isAfter(start)) continue;
        if (!includeWeekends && at.weekday > DateTime.friday) continue;
        firings.add(at.toUtc());
      }
    }

    firings.sort((a, b) => a.compareTo(b));
    return firings;
  }

  /// A firing, written down as sent and not yet answered.
  ///
  /// The outcome starts [ReminderOutcome.unknown] and stays there until a
  /// later check can prove otherwise — which is also the honest resting state
  /// for a reminder whose day nobody was around to observe.
  static ReminderEvent record({
    required DateTime sentAt,
    required List<ContributionDay> days,
  }) {
    final at = sentAt.toUtc();
    final day = dayOf(days, at);
    final covered = _startedBefore(day, at);

    return ReminderEvent(
      id: idFor(at),
      sentAt: at,
      streakAtSend: _streakBefore(days, utcDateLabel(at)),
      // The scheduled notification asserts the day is empty — that is the
      // text the user read — so the record carries the same claim unless the
      // calendar can already show it was wrong.
      contributionsAtSend: covered ? day!.count : 0,
      hoursLeft: StreakCalculator.nextDeadline(at).difference(at).inHours,
      outcome: ReminderOutcome.unknown,
    );
  }

  /// The event's id, derived from when it fired.
  ///
  /// PLAN.md section 4 expects a client-generated UUID because reminder
  /// events have no natural key. Reconstructing firings gave them one: two
  /// reminders cannot fire at the same instant. Deriving the id from it makes
  /// recording idempotent even if the high-water mark is lost — a re-run
  /// rewrites the same row instead of inflating the save count, which is
  /// exactly the property the UUID was there to buy.
  static String idFor(DateTime sentAt) =>
      'rem-${sentAt.toUtc().toIso8601String()}';

  /// Settles an open event, or returns null while the answer is not yet
  /// knowable.
  ///
  /// [syncedAt] is when the mirror was last refreshed. It gates the one
  /// conclusion that could be wrong in the dangerous direction: a day reads
  /// as empty both when nothing was committed and when nobody has looked
  /// since. Only a mirror refreshed after the deadline is allowed to call a
  /// streak broken.
  static ReminderEvent? resolve(
    ReminderEvent event, {
    required List<ContributionDay> days,
    required DateTime now,
    DateTime? syncedAt,
  }) {
    if (event.outcome != ReminderOutcome.unknown) return null;

    final day = dayOf(days, event.sentAt);
    if (day == null) return null;

    final first = day.firstContributionAt;

    if (day.count > 0) {
      if (first != null && first.isBefore(event.sentAt)) {
        // The day was already covered when we nagged. Recording that plainly
        // is what keeps the save count honest — this is the app's own false
        // alarm, and it is the failure direction PLAN.md section 1 accepts.
        return _settle(
          event,
          ReminderOutcome.alreadySafe,
          at: first,
          contributionsAtSend: day.count,
        );
      }
      // Either the first contribution landed after the nag, or the day has no
      // commit times at all — private repositories and issue-only days never
      // get them. The nag went out claiming the day was empty, and the day
      // ended covered, so it counts; without a time it simply contributes no
      // response latency.
      return _settle(event, ReminderOutcome.saved, at: first);
    }

    final deadline = StreakCalculator.nextDeadline(event.sentAt);
    if (now.toUtc().isAfter(deadline) &&
        syncedAt != null &&
        syncedAt.toUtc().isAfter(deadline)) {
      return _settle(event, ReminderOutcome.broken, at: deadline);
    }

    // Still in play, or the mirror is too old to be believed about a zero.
    return null;
  }

  /// The calendar row for the contribution day [at] falls in.
  ///
  /// UTC, because that is the clock the contribution graph is stamped in —
  /// a 22:00 reminder in Los Angeles is guarding the day it fires inside in
  /// UTC, not the local one.
  static ContributionDay? dayOf(List<ContributionDay> days, DateTime at) {
    final label = utcDateLabel(at);
    for (final day in days) {
      if (day.date == label) return day;
    }
    return null;
  }

  static ReminderEvent _settle(
    ReminderEvent event,
    ReminderOutcome outcome, {
    DateTime? at,
    int? contributionsAtSend,
  }) => ReminderEvent(
    id: event.id,
    sentAt: event.sentAt,
    streakAtSend: event.streakAtSend,
    contributionsAtSend: contributionsAtSend ?? event.contributionsAtSend,
    outcome: outcome,
    hoursLeft: event.hoursLeft,
    outcomeAt: at?.toUtc(),
  );

  static bool _startedBefore(ContributionDay? day, DateTime at) {
    final first = day?.firstContributionAt;
    return first != null && first.isBefore(at);
  }

  /// Consecutive contribution days ending the day before [label].
  ///
  /// The pending-today rule, applied to the reminder's own day: whatever
  /// happens after the nag is what the outcome is for, so the streak it was
  /// sent to protect runs up to the previous day.
  static int _streakBefore(List<ContributionDay> days, String label) {
    var streak = 0;
    for (var i = days.length - 1; i >= 0; i--) {
      if (days[i].date.compareTo(label) >= 0) continue;
      if (days[i].count == 0) break;
      streak++;
    }
    return streak;
  }
}
