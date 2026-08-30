import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_service.dart';

/// Turns reminder settings into notifications scheduled with the OS.
///
/// The design is schedule-optimistically, cancel-when-safe (PHASE3.md): every
/// reminder is registered in advance and the periodic check withdraws the ones
/// the day turns out not to need. Nothing here knows whether the user is safe —
/// this only guarantees the nag exists, because if the check never runs the
/// worst outcome must be a redundant reminder, never a silent broken streak.
class ReminderScheduler {
  const ReminderScheduler({required this.notifications});

  final NotificationService notifications;

  /// Scheduled reminders own ids from here up; the transient notifications
  /// [NotificationService] shows directly stay below.
  static const _idBase = 100;

  /// Runway a reminder time is warned about in settings: enough to matter,
  /// not enough to be comfortable.
  static const warnRunway = Duration(hours: 2);

  /// Runway below which [apply] refuses to schedule at all — a nudge nobody
  /// could act on in time.
  static const minRunway = Duration(minutes: 15);

  /// How long [time] ("HH:mm") in [zoneName] leaves between firing and the
  /// next UTC midnight — the deadline of the contribution day in progress.
  ///
  /// A repeating daily reminder is never "after" the deadline: whatever the
  /// zone, it fires inside some UTC day and leaves this same runway every
  /// day. What differs between choices of time is only how much. (The local
  /// and UTC dates disagreeing means nothing here — an Auckland 09:00
  /// reminder fires on the previous UTC date with four useful hours left.)
  ///
  /// Null when the zone or the time cannot be parsed.
  static Duration? runwayOf(String time, String zoneName) {
    try {
      final zone = tz.getLocation(zoneName);
      final now = tz.TZDateTime.now(zone);
      final parts = time.split(':');
      final utc = tz.TZDateTime(
        zone,
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      ).toUtc();
      return DateTime.utc(utc.year, utc.month, utc.day + 1).difference(utc);
    } catch (_) {
      // An unresolvable zone or a malformed time is the picker's problem to
      // report, not a reason to warn about the deadline.
      return null;
    }
  }

  /// True when [time] fires with under [warnRunway] left. The settings screen
  /// warns about these.
  static bool tooCloseToDeadline(String time, String zoneName) {
    final runway = runwayOf(time, zoneName);
    return runway != null && runway < warnRunway;
  }

  /// Replaces whatever is scheduled with what the given settings ask for.
  ///
  /// Cancel-and-replace rather than diffing: the whole set is derived from
  /// settings in one pass, so there is no partial state to get out of sync.
  Future<void> apply({
    required bool enabled,
    required List<String> times,
    required String timezone,
    required bool includeWeekends,
  }) async {
    for (final request in await notifications.pending()) {
      if (request.id >= _idBase) await notifications.cancel(request.id);
    }
    if (!enabled || times.isEmpty) return;

    final tz.Location zone;
    try {
      zone = tz.getLocation(timezone);
    } catch (_) {
      // Better no reminder than one firing at a guessed hour. The timezone
      // card is already showing a warning for this state.
      return;
    }

    final exact = (await notifications.permissions()).exactAlarmsAllowed;

    for (var i = 0; i < times.length; i++) {
      final time = times[i];
      final runway = runwayOf(time, timezone);
      if (runway != null && runway < minRunway) continue;

      final parts = time.split(':');
      final hour = int.tryParse(parts[0]);
      final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
      if (hour == null || minute == null) continue;

      if (includeWeekends) {
        await _schedule(
          id: _idBase + i * 10,
          at: _next(zone, hour, minute),
          repeat: DateTimeComponents.time,
          exact: exact,
        );
      } else {
        // No "daily except weekends" repeat exists, so the quiet-weekend
        // choice becomes five weekly schedules per time.
        for (var day = DateTime.monday; day <= DateTime.friday; day++) {
          await _schedule(
            id: _idBase + i * 10 + day,
            at: _next(zone, hour, minute, weekday: day),
            repeat: DateTimeComponents.dayOfWeekAndTime,
            exact: exact,
          );
        }
      }
    }
  }

  /// Withdraws everything, scheduled and already showing.
  ///
  /// [apply] only touches the ids it owns, because a transient notification
  /// is not its business. Sign-out is the opposite case: a nag left on the
  /// lock screen for an account the phone no longer holds a token for is
  /// worse than useless, so this clears the lot.
  Future<void> cancelAll() => notifications.cancelAll();

  Future<void> _schedule({
    required int id,
    required tz.TZDateTime at,
    required DateTimeComponents repeat,
    required bool exact,
  }) => notifications.scheduleReminder(
    id: id,
    // Static copy, written at schedule time when nothing is known about the
    // day. It is phrased as our best knowledge rather than a fact, because
    // when the cancelling check could not run, firing anyway is the point.
    title: 'One last commit?',
    body: 'Nothing has counted toward your streak yet today.',
    at: at,
    repeat: repeat,
    exact: exact,
  );

  /// The next moment the wall clock in [zone] reads [hour]:[minute] — on
  /// [weekday] when given. Built from calendar components rather than added
  /// durations so a DST jump cannot shift the wall time.
  static tz.TZDateTime _next(
    tz.Location zone,
    int hour,
    int minute, {
    int? weekday,
  }) {
    final now = tz.TZDateTime.now(zone);
    var at = tz.TZDateTime(zone, now.year, now.month, now.day, hour, minute);
    var days = 0;
    while (!at.isAfter(now) || (weekday != null && at.weekday != weekday)) {
      days++;
      at = tz.TZDateTime(
        zone,
        now.year,
        now.month,
        now.day + days,
        hour,
        minute,
      );
    }
    return at;
  }
}
