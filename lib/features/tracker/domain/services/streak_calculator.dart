import '../../../../core/util/utc_date.dart';
import '../entities/entities.dart';

/// Derives [StreakStatus] and [OlcInsights] from raw contribution days.
///
/// Lives in the domain, computed on the client, with exactly one
/// implementation. That is deliberate: a server-side copy of these rules would
/// go stale offline and drift from this one. See PLAN.md section 4.
class StreakCalculator {
  const StreakCalculator._();

  /// [days] must be oldest-first.
  ///
  /// Which row is *today* is decided by the clock, never by taking `days.last`
  /// on trust. The mirror is written by a sync that may have happened before
  /// the UTC day rolled over, and the deadline is derived from [now] either
  /// way — so reading a count off the last row would let the app pair
  /// yesterday's five contributions with today's countdown and report a safe
  /// day on an empty one. PLAN section 1 calls that the one direction this app
  /// cannot fail in.
  ///
  /// Returns null when there is nothing to compute from — a brand-new install
  /// has no streak, which is different from a streak of zero.
  static StreakStatus? streakFrom(
    List<ContributionDay> days, {
    required DateTime now,
    DataFreshness freshness = DataFreshness.fresh,
  }) {
    if (days.isEmpty) return null;

    final todayLabel = utcDateLabel(now);
    final last = days.last;
    final hasToday = last.date == todayLabel;

    // No row for today means nobody has looked at today yet, whatever the
    // sync clock says. Treat it as an empty day — which nags — and refuse to
    // call the answer fresh.
    final todayCount = hasToday ? last.count : 0;
    final effective = hasToday
        ? freshness
        : (freshness == DataFreshness.error
              ? DataFreshness.error
              : DataFreshness.stale);

    // The pending-today rule. A streak of 47 with nothing yet today is still
    // 47 and at risk — never 0. Today only joins the streak once it has a
    // contribution; until then the count runs to yesterday.
    //
    // The skip applies only to a genuine today row. When the last row is
    // yesterday, a zero there is a real empty day and the streak is broken.
    var current = 0;
    for (var i = days.length - 1; i >= 0; i--) {
      final day = days[i];
      if (hasToday && i == days.length - 1 && day.count == 0) continue;
      if (day.count == 0) break;
      current++;
    }

    var longest = 0;
    var run = 0;
    for (final day in days) {
      run = day.count > 0 ? run + 1 : 0;
      if (run > longest) longest = run;
    }

    final lastActive = days.lastWhere((d) => d.count > 0, orElse: () => last);

    // The run that just ended. Only meaningful once the current one is gone —
    // it is what turns "0 day streak" into "your 23 days ended yesterday".
    var previous = 0;
    if (current == 0 && lastActive.count > 0) {
      final end = days.indexOf(lastActive);
      for (var i = end; i >= 0 && days[i].count > 0; i--) {
        previous++;
      }
    }

    return StreakStatus(
      current: current,
      longest: longest,
      todayCount: todayCount,
      todayDate: todayLabel,
      deadlineUtc: nextDeadline(now),
      checkedAt: now.toUtc(),
      lastContributionDate: lastActive.count > 0 ? lastActive.date : null,
      previousStreak: previous,
      weekTotal: _tail(days, 7),
      monthTotal: _tail(days, 30),
      freshness: effective,
    );
  }

  /// The next UTC midnight. Contributions are stamped in UTC, so this is when
  /// today's window actually closes — not local midnight, which can be up to
  /// fourteen hours away from it.
  static DateTime nextDeadline(DateTime now) {
    final u = now.toUtc();
    return DateTime.utc(u.year, u.month, u.day).add(const Duration(days: 1));
  }

  static int _tail(List<ContributionDay> days, int n) {
    final slice = days.length <= n ? days : days.sublist(days.length - n);
    return slice.fold(0, (sum, d) => sum + d.count);
  }

  /// Aggregates for the analysis page.
  ///
  /// Two windows, deliberately. Rhythm, composition, breaks and trend come
  /// from GitHub's calendar, which reaches back a year — filtering those by
  /// the install date would blank the page on a fresh install for no reason.
  /// Saves and response times genuinely start at install, because they come
  /// from reminders that did not exist before it.
  static OlcInsights insightsFrom({
    required List<ContributionDay> days,
    required List<ReminderEvent> reminders,
    required List<ContributionActivity> activity,
    required DateTime installedAt,
  }) {
    // Everything GitHub knows.
    final era = days;

    // Only what happened while the app was watching.
    final installedLabel = utcDateLabel(installedAt);
    final watched = days
        .where((d) => d.date.compareTo(installedLabel) >= 0)
        .toList();

    final saved = reminders
        .where((r) => r.outcome == ReminderOutcome.saved)
        .toList();

    final responses =
        saved.map((r) => r.responseTime).whereType<Duration>().toList()..sort();

    // Smallest gap between a day's last contribution and its deadline. This is
    // the "11 minutes to spare" number.
    Duration? closest;
    for (final d in era) {
      final last = d.lastContributionAt;
      if (last == null) continue;
      final deadline = nextDeadline(last);
      final margin = deadline.difference(last.toUtc());
      if (!margin.isNegative && (closest == null || margin < closest)) {
        closest = margin;
      }
    }

    final hours = List<int>.filled(24, 0);
    final weekdays = List<int>.filled(7, 0);
    for (final d in era) {
      final at = d.lastContributionAt;
      if (at == null) continue;
      final local = at.toLocal();
      hours[local.hour] += d.count;
      weekdays[local.weekday - 1] += d.count;
    }

    final composition = <ContributionType, int>{};
    for (final a in activity) {
      composition.update(a.type, (v) => v + a.count, ifAbsent: () => a.count);
    }

    return OlcInsights(
      installedAt: installedAt,
      daysTracked: era.length,
      daysWatched: watched.length,
      daysWithContributions: era.where((d) => d.hasContributions).length,
      saves: saved.length,
      remindersSent: reminders.length,
      closestCall: closest,
      medianResponseTime: responses.isEmpty
          ? null
          : responses[responses.length ~/ 2],
      composition: composition,
      uncountedPushes: era.fold(0, (s, d) => s + d.uncountedPushes),
      hourHistogram: hours,
      weekdayHistogram: weekdays,
      breaks: _breaksIn(era),
      longestStreakInEra: _longestIn(era),
      rollingWeekAverage: _rolling(era, 7),
    );
  }

  static List<StreakBreak> _breaksIn(List<ContributionDay> era) {
    final breaks = <StreakBreak>[];
    var run = 0;
    for (var i = 0; i < era.length; i++) {
      if (era[i].count > 0) {
        run++;
        continue;
      }
      if (run > 0) {
        final recovered = era
            .skip(i)
            .firstWhere((d) => d.count > 0, orElse: () => era[i]);
        breaks.add(
          StreakBreak(
            brokeOn: era[i].date,
            lengthBefore: run,
            recoveredOn: recovered.count > 0 ? recovered.date : null,
          ),
        );
      }
      run = 0;
    }
    return breaks;
  }

  static int _longestIn(List<ContributionDay> era) {
    var longest = 0;
    var run = 0;
    for (final d in era) {
      run = d.count > 0 ? run + 1 : 0;
      if (run > longest) longest = run;
    }
    return longest;
  }

  static List<double> _rolling(List<ContributionDay> era, int window) {
    if (era.length < window) return const [];
    return [
      for (var i = window; i <= era.length; i++)
        era.sublist(i - window, i).fold<int>(0, (s, d) => s + d.count) / window,
    ];
  }
}
