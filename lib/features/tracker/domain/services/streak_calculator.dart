import '../entities/entities.dart';

/// Derives [StreakStatus] and [OlcInsights] from raw contribution days.
///
/// Lives in the domain, computed on the client, with exactly one
/// implementation. That is deliberate: a server-side copy of these rules would
/// go stale offline and drift from this one. See PLAN.md section 4.
class StreakCalculator {
  const StreakCalculator._();

  /// [days] must be oldest-first and end with today.
  ///
  /// Returns null when there is nothing to compute from — a brand-new install
  /// has no streak, which is different from a streak of zero.
  static StreakStatus? streakFrom(
    List<ContributionDay> days, {
    required DateTime now,
    DataFreshness freshness = DataFreshness.fresh,
  }) {
    if (days.isEmpty) return null;

    final today = days.last;

    // The pending-today rule. A streak of 47 with nothing yet today is still
    // 47 and at risk — never 0. Today only joins the streak once it has a
    // contribution; until then the count runs to yesterday.
    var current = 0;
    for (var i = days.length - 1; i >= 0; i--) {
      final day = days[i];
      if (i == days.length - 1 && day.count == 0) continue;
      if (day.count == 0) break;
      current++;
    }

    var longest = 0;
    var run = 0;
    for (final day in days) {
      run = day.count > 0 ? run + 1 : 0;
      if (run > longest) longest = run;
    }

    // A run that reaches the oldest day we hold may extend past it. GitHub
    // caps a query at one year, so the honest answer is "at least this", and
    // the caller stitches another year when it matters.
    if (current >= days.length) current = days.length;

    final lastActive = days.lastWhere((d) => d.count > 0, orElse: () => today);

    return StreakStatus(
      current: current,
      longest: longest,
      todayCount: today.count,
      todayDate: today.date,
      deadlineUtc: nextDeadline(now),
      checkedAt: now.toUtc(),
      lastContributionDate: lastActive.count > 0 ? lastActive.date : null,
      weekTotal: _tail(days, 7),
      monthTotal: _tail(days, 30),
      freshness: freshness,
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
    final installedLabel = _label(installedAt);
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
      countedPushes: era.fold(0, (s, d) => s + d.countedPushes),
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

  static String _label(DateTime d) {
    final u = d.toUtc();
    return '${u.year.toString().padLeft(4, '0')}-'
        '${u.month.toString().padLeft(2, '0')}-'
        '${u.day.toString().padLeft(2, '0')}';
  }
}
