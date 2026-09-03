import 'package:flutter_test/flutter_test.dart';
import 'package:olc/features/tracker/domain/entities/entities.dart';
import 'package:olc/features/tracker/domain/services/streak_calculator.dart';

import '../support/builders.dart';

void main() {
  final now = DateTime.utc(2026, 8, 26, 15);

  group('which row is today', () {
    // The whole class of stale-input bugs. Every other test in this file
    // builds days that end on `now`, so none of them could ever have caught
    // a mirror written before the UTC day rolled over.

    test('a mirror that stops at yesterday is never reported as safe', () {
      // Synced at 23:50 UTC with five contributions; it is now 00:30 the next
      // day. Reading the count off days.last would pair yesterday's five with
      // today's countdown and render the green "Safe today" card on an empty
      // day.
      final streak = StreakCalculator.streakFrom(
        daysEnding(now.subtract(const Duration(days: 1)), [1, 2, 1, 3, 5]),
        now: now,
      )!;

      expect(streak.todayCount, 0);
      expect(streak.isSafeToday, isFalse);
      expect(streak.atRisk, isTrue);
      expect(streak.todayDate, label(now));
    });

    test('the streak itself survives the rollover', () {
      // Yesterday was covered, so the run is real and still five long. It is
      // today that is unknown, not the history.
      final streak = StreakCalculator.streakFrom(
        daysEnding(now.subtract(const Duration(days: 1)), [1, 2, 1, 3, 5]),
        now: now,
      )!;

      expect(streak.current, 5);
    });

    test('a missing today row is never called fresh', () {
      final streak = StreakCalculator.streakFrom(
        daysEnding(now.subtract(const Duration(days: 1)), [1, 1]),
        now: now,
        freshness: DataFreshness.fresh,
      )!;

      // The sync clock can say the mirror is minutes old and still hold
      // nothing about the day the user is currently in.
      expect(streak.freshness, DataFreshness.stale);
      expect(streak.isUncertain, isTrue);
    });

    test('a trailing zero on a stale mirror is a real broken day', () {
      // The pending-today skip applies only to a genuine today row. Yesterday
      // ending in a zero means the streak is already gone.
      final streak = StreakCalculator.streakFrom(
        daysEnding(now.subtract(const Duration(days: 1)), [4, 4, 4, 0]),
        now: now,
      )!;

      expect(streak.current, 0);
    });

    test('an error stays an error rather than softening to stale', () {
      final streak = StreakCalculator.streakFrom(
        daysEnding(now.subtract(const Duration(days: 1)), [1, 1]),
        now: now,
        freshness: DataFreshness.error,
      )!;

      expect(streak.freshness, DataFreshness.error);
    });
  });

  group('the pending-today rule', () {
    test('an empty today does not break the streak', () {
      // Four active days, then nothing yet today. The streak is 4 and at
      // risk — not 0. Getting this wrong makes the app feel broken every
      // morning.
      final streak = StreakCalculator.streakFrom(
        daysEnding(now, [1, 2, 1, 3, 0]),
        now: now,
      )!;

      expect(streak.current, 4);
      expect(streak.atRisk, isTrue);
      expect(streak.isSafeToday, isFalse);
    });

    test('today joins the streak once it has a contribution', () {
      final streak = StreakCalculator.streakFrom(
        daysEnding(now, [1, 2, 1, 3, 2]),
        now: now,
      )!;

      expect(streak.current, 5);
      expect(streak.atRisk, isFalse);
    });

    test('a gap yesterday means the streak is already broken', () {
      final streak = StreakCalculator.streakFrom(
        daysEnding(now, [4, 4, 4, 0, 0]),
        now: now,
      )!;

      expect(streak.current, 0);
      expect(streak.atRisk, isTrue);
    });

    test('a gap yesterday with work today starts a new streak of one', () {
      final streak = StreakCalculator.streakFrom(
        daysEnding(now, [4, 4, 4, 0, 2]),
        now: now,
      )!;

      expect(streak.current, 1);
    });
  });

  group('window boundaries', () {
    test('a streak filling the whole window is capped at what we hold', () {
      // GitHub caps a query at one year. A run reaching the oldest day we
      // have may extend past it, so the honest answer is bounded by the
      // window rather than invented.
      final days = daysEnding(now, List.filled(365, 3));
      final streak = StreakCalculator.streakFrom(days, now: now)!;

      expect(streak.current, 365);
      expect(streak.current, lessThanOrEqualTo(days.length));
    });

    test('longest scans the whole window, not just the tail', () {
      final streak = StreakCalculator.streakFrom(
        daysEnding(now, [1, 1, 1, 1, 1, 0, 2, 0]),
        now: now,
      )!;

      expect(streak.longest, 5);
      expect(streak.current, 1);
    });

    test('an empty calendar yields no streak at all', () {
      // Null, not zero: a new install has no streak, which is a different
      // thing from a streak that has ended.
      expect(StreakCalculator.streakFrom(const [], now: now), isNull);
    });
  });

  group('the deadline', () {
    test('is the next UTC midnight, not local midnight', () {
      final deadline = StreakCalculator.nextDeadline(
        DateTime.utc(2026, 8, 26, 23, 59),
      );

      expect(deadline, DateTime.utc(2026, 8, 27));
      expect(deadline.isUtc, isTrue);
    });

    test('remaining never goes negative once the deadline has passed', () {
      final streak = StreakCalculator.streakFrom(
        daysEnding(now, [1, 1]),
        now: now,
      )!;

      final after = streak.deadlineUtc.add(const Duration(hours: 3));
      expect(streak.remaining(after), Duration.zero);
    });
  });

  group('totals and freshness', () {
    test('week and month totals cover the trailing window', () {
      final streak = StreakCalculator.streakFrom(
        daysEnding(now, List.filled(40, 2)),
        now: now,
      )!;

      expect(streak.weekTotal, 14);
      expect(streak.monthTotal, 60);
    });

    test('anything but fresh is reported as uncertain', () {
      for (final f in [DataFreshness.stale, DataFreshness.error]) {
        final streak = StreakCalculator.streakFrom(
          daysEnding(now, [1, 1]),
          now: now,
          freshness: f,
        )!;
        expect(streak.isUncertain, isTrue, reason: '$f should be uncertain');
      }
    });
  });

  group('insights', () {
    test('counts saves and derives a median response time', () {
      final sent = DateTime.utc(2026, 8, 20, 20, 30);
      final insights = StreakCalculator.insightsFrom(
        days: daysEnding(now, [1, 0, 2, 1, 1]),
        reminders: [
          ReminderEvent(
            id: 'a',
            sentAt: sent,
            streakAtSend: 3,
            contributionsAtSend: 0,
            outcome: ReminderOutcome.saved,
            outcomeAt: sent.add(const Duration(minutes: 10)),
          ),
          ReminderEvent(
            id: 'b',
            sentAt: sent,
            streakAtSend: 3,
            contributionsAtSend: 0,
            outcome: ReminderOutcome.saved,
            outcomeAt: sent.add(const Duration(minutes: 30)),
          ),
          ReminderEvent(
            id: 'c',
            sentAt: sent,
            streakAtSend: 3,
            contributionsAtSend: 0,
            outcome: ReminderOutcome.broken,
          ),
        ],
        activity: const [],
        installedAt: now.subtract(const Duration(days: 10)),
      );

      expect(insights.saves, 2);
      expect(insights.remindersSent, 3);
      expect(insights.medianResponseTime, const Duration(minutes: 30));
    });

    test('records a break with the run that preceded it', () {
      final insights = StreakCalculator.insightsFrom(
        days: daysEnding(now, [1, 1, 1, 0, 2]),
        reminders: const [],
        activity: const [],
        installedAt: now.subtract(const Duration(days: 10)),
      );

      expect(insights.breaks, hasLength(1));
      expect(insights.breaks.single.lengthBefore, 3);
      expect(insights.breaks.single.hasRecovered, isTrue);
    });

    test('consistency is zero rather than NaN with no days tracked', () {
      final insights = StreakCalculator.insightsFrom(
        days: const [],
        reminders: const [],
        activity: const [],
        installedAt: now,
      );

      expect(insights.consistency, 0);
      expect(insights.peakHour, isNull);
    });
  });
}
