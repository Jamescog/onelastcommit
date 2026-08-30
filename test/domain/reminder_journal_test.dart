import 'package:flutter_test/flutter_test.dart';
import 'package:olc/features/tracker/domain/entities/entities.dart';
import 'package:olc/features/tracker/domain/services/reminder_journal.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Reminder history is the one table nothing can rebuild, so both halves of
/// it are pinned here: which firings get reconstructed, and what each one is
/// allowed to conclude.
///
/// Fixed-offset zones (`Etc/GMT±N`, POSIX sign convention: GMT-13 is UTC+13)
/// keep the instants exact — a named city zone would shift them with DST.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  ContributionDay day(
    String date, {
    int count = 0,
    DateTime? first,
    DateTime? last,
  }) => ContributionDay(
    date: date,
    count: count,
    level: count == 0 ? 0 : 1,
    firstContributionAt: first,
    lastContributionAt: last ?? first,
  );

  group('firings are reconstructed from the schedule', () {
    test('one per day in the window, at the chosen local time', () {
      final firings = ReminderJournal.firingsBetween(
        times: const ['20:00'],
        timezone: 'UTC',
        includeWeekends: true,
        after: DateTime.utc(2026, 8, 24, 12),
        until: DateTime.utc(2026, 8, 27, 12),
      );

      expect(firings, [
        DateTime.utc(2026, 8, 24, 20),
        DateTime.utc(2026, 8, 25, 20),
        DateTime.utc(2026, 8, 26, 20),
      ]);
    });

    test('the window is exclusive at the low end, inclusive at the high', () {
      // The high-water mark is the previous check, and that check already
      // recorded the firing that landed on it.
      expect(
        ReminderJournal.firingsBetween(
          times: const ['20:00'],
          timezone: 'UTC',
          includeWeekends: true,
          after: DateTime.utc(2026, 8, 24, 20),
          until: DateTime.utc(2026, 8, 25, 20),
        ),
        [DateTime.utc(2026, 8, 25, 20)],
      );
    });

    test('local times become the UTC instants they actually fired at', () {
      // 22:00 in a UTC-8 zone is 06:00 the next UTC day — the reminder is
      // guarding a day that is only six hours old.
      expect(
        ReminderJournal.firingsBetween(
          times: const ['22:00'],
          timezone: 'Etc/GMT+8',
          includeWeekends: true,
          after: DateTime.utc(2026, 8, 25),
          until: DateTime.utc(2026, 8, 26),
        ),
        [DateTime.utc(2026, 8, 25, 6)],
      );
    });

    test('quiet weekends produce no Saturday or Sunday firings', () {
      // 2026-08-29 and 2026-08-30 are a Saturday and a Sunday.
      final firings = ReminderJournal.firingsBetween(
        times: const ['20:00'],
        timezone: 'UTC',
        includeWeekends: false,
        after: DateTime.utc(2026, 8, 28),
        until: DateTime.utc(2026, 8, 31, 23),
      );

      expect(firings, [
        DateTime.utc(2026, 8, 28, 20),
        DateTime.utc(2026, 8, 31, 20),
      ]);
    });

    test('a long gap is capped rather than backfilled', () {
      final firings = ReminderJournal.firingsBetween(
        times: const ['20:00'],
        timezone: 'UTC',
        includeWeekends: true,
        after: DateTime.utc(2026, 1, 1),
        until: DateTime.utc(2026, 8, 27, 12),
      );

      expect(firings.length, lessThanOrEqualTo(7));
      expect(firings.first, DateTime.utc(2026, 8, 20, 20));
    });

    test('nothing is claimed for an unreadable zone or a bad time', () {
      expect(
        ReminderJournal.firingsBetween(
          times: const ['20:00'],
          timezone: 'Not/AZone',
          includeWeekends: true,
          after: DateTime.utc(2026, 8, 25),
          until: DateTime.utc(2026, 8, 26),
        ),
        isEmpty,
      );
      expect(
        ReminderJournal.firingsBetween(
          times: const ['later'],
          timezone: 'UTC',
          includeWeekends: true,
          after: DateTime.utc(2026, 8, 25),
          until: DateTime.utc(2026, 8, 26),
        ),
        isEmpty,
      );
    });

    test('the id is the firing instant, so a re-run rewrites one row', () {
      final at = DateTime.utc(2026, 8, 26, 20);
      expect(ReminderJournal.idFor(at), ReminderJournal.idFor(at));
      expect(
        ReminderJournal.idFor(at),
        isNot(ReminderJournal.idFor(at.add(const Duration(hours: 1)))),
      );
    });
  });

  group('a recorded firing', () {
    final days = [
      day('2026-08-24', count: 3),
      day('2026-08-25', count: 2),
      day('2026-08-26'),
    ];

    test('carries the streak it was sent to protect and its runway', () {
      final event = ReminderJournal.record(
        sentAt: DateTime.utc(2026, 8, 26, 20, 30),
        days: days,
      );

      expect(event.streakAtSend, 2);
      expect(event.contributionsAtSend, 0);
      expect(event.hoursLeft, 3);
      expect(event.outcome, ReminderOutcome.unknown);
    });
  });

  group('outcomes', () {
    final sentAt = DateTime.utc(2026, 8, 26, 20, 30);
    final open = ReminderJournal.record(sentAt: sentAt, days: const []);

    test('saved when the first contribution lands after the nag', () {
      final settled = ReminderJournal.resolve(
        open,
        days: [
          day('2026-08-26', count: 4, first: DateTime.utc(2026, 8, 26, 21, 7)),
        ],
        now: DateTime.utc(2026, 8, 26, 22),
      );

      expect(settled!.outcome, ReminderOutcome.saved);
      expect(settled.responseTime, const Duration(minutes: 37));
    });

    test('saved with no latency when the day carries no commit times', () {
      // Private repositories and issue-only days never get one. The day still
      // ended covered, so the reminder still counts.
      final settled = ReminderJournal.resolve(
        open,
        days: [day('2026-08-26', count: 4)],
        now: DateTime.utc(2026, 8, 26, 22),
      );

      expect(settled!.outcome, ReminderOutcome.saved);
      expect(settled.responseTime, isNull);
    });

    test('already safe when the day was covered before the nag', () {
      final settled = ReminderJournal.resolve(
        open,
        days: [
          day('2026-08-26', count: 4, first: DateTime.utc(2026, 8, 26, 9)),
        ],
        now: DateTime.utc(2026, 8, 26, 22),
      );

      expect(settled!.outcome, ReminderOutcome.alreadySafe);
      expect(settled.contributionsAtSend, 4);
      expect(settled.responseTime, isNull);
    });

    test('broken only once a refreshed mirror has seen the day close', () {
      final days = [day('2026-08-26')];
      final afterDeadline = DateTime.utc(2026, 8, 27, 9);

      // The day is over, but nothing has looked at GitHub since it closed. A
      // zero here is our own staleness, not a broken streak — PLAN.md
      // section 1's one forbidden direction.
      expect(
        ReminderJournal.resolve(
          open,
          days: days,
          now: afterDeadline,
          syncedAt: DateTime.utc(2026, 8, 26, 21),
        ),
        isNull,
      );

      final settled = ReminderJournal.resolve(
        open,
        days: days,
        now: afterDeadline,
        syncedAt: afterDeadline,
      );
      expect(settled!.outcome, ReminderOutcome.broken);
      expect(settled.outcomeAt, DateTime.utc(2026, 8, 27));
    });

    test('stays open while the day is still in play', () {
      expect(
        ReminderJournal.resolve(
          open,
          days: [day('2026-08-26')],
          now: DateTime.utc(2026, 8, 26, 21),
          syncedAt: DateTime.utc(2026, 8, 26, 21),
        ),
        isNull,
      );
    });

    test('stays open when the calendar has nothing for the day', () {
      expect(
        ReminderJournal.resolve(
          open,
          days: const [],
          now: DateTime.utc(2026, 8, 28),
          syncedAt: DateTime.utc(2026, 8, 28),
        ),
        isNull,
      );
    });

    test('a settled event is never revisited', () {
      final settled = ReminderJournal.resolve(
        open,
        days: [day('2026-08-26', count: 4)],
        now: DateTime.utc(2026, 8, 26, 22),
      )!;

      expect(
        ReminderJournal.resolve(
          settled,
          days: [day('2026-08-26', count: 9)],
          now: DateTime.utc(2026, 8, 27, 12),
        ),
        isNull,
      );
    });
  });
}
