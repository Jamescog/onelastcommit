import 'package:flutter_test/flutter_test.dart';
import 'package:olc/core/util/reminder_scheduler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

/// The runway calculation decides which times settings warns about and which
/// the scheduler refuses, so both sides ride on it being right.
///
/// Fixed-offset zones (`Etc/GMT±N`, POSIX sign convention: GMT-13 is UTC+13)
/// keep the expectations exact — a named city zone would shift them with DST.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('runway is the time from firing to the next UTC midnight', () {
    // 23:30 UTC fires half an hour before the day closes.
    expect(
      ReminderScheduler.runwayOf('23:30', 'UTC'),
      const Duration(minutes: 30),
    );
    // At UTC+13, 22:00 local is 09:00 UTC — fifteen hours of the same UTC
    // day left. PLAN.md's Auckland example calls this time useless; the
    // arithmetic says otherwise, which is why the check measures runway
    // instead of comparing dates.
    expect(
      ReminderScheduler.runwayOf('22:00', 'Etc/GMT-13'),
      const Duration(hours: 15),
    );
    // At UTC-8, 22:00 local is 06:00 the next UTC day — a fresh day with
    // eighteen hours left, not a missed deadline. A date comparison would
    // have refused every US evening.
    expect(
      ReminderScheduler.runwayOf('22:00', 'Etc/GMT+8'),
      const Duration(hours: 18),
    );
    // A morning east of UTC fires late in the previous UTC day and is still
    // a usable last call.
    expect(
      ReminderScheduler.runwayOf('09:00', 'Etc/GMT-13'),
      const Duration(hours: 4),
    );
  });

  test('only genuinely tight times are flagged', () {
    expect(ReminderScheduler.tooCloseToDeadline('23:30', 'UTC'), true);
    expect(ReminderScheduler.tooCloseToDeadline('21:30', 'UTC'), false);
    expect(ReminderScheduler.tooCloseToDeadline('22:00', 'Etc/GMT-13'), false);
    expect(ReminderScheduler.tooCloseToDeadline('22:00', 'Etc/GMT+8'), false);
  });

  test('garbage input warns about nothing', () {
    expect(ReminderScheduler.runwayOf('22:00', 'Not/AZone'), null);
    expect(ReminderScheduler.runwayOf('later', 'UTC'), null);
    expect(ReminderScheduler.tooCloseToDeadline('later', 'UTC'), false);
  });

  group('offered times', () {
    test('the app publishes one list, not two', () {
      // Setup offered sixteen times and settings eleven. A 09:00 chosen at
      // setup had no chip in settings: invisible, unremovable, still firing.
      expect(ReminderScheduler.offeredTimes, isNotEmpty);
      expect(
        ReminderScheduler.offeredTimes.toSet().length,
        ReminderScheduler.offeredTimes.length,
      );
      final sorted = [...ReminderScheduler.offeredTimes]..sort();
      expect(ReminderScheduler.offeredTimes, sorted);
    });
  });
}
