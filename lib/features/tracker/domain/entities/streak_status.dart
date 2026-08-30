import 'package:equatable/equatable.dart';

/// How much the app trusts what it is showing.
///
/// Rendered on every surface that shows a streak. The app must never present
/// an uncertain state as a certain one: silence is the fatal direction here,
/// and so is confident wrongness.
enum DataFreshness {
  /// Checked against GitHub recently enough to act on.
  fresh,

  /// Served from cache. Real, but possibly out of date.
  stale,

  /// The last check failed. We do not know.
  error,
}

/// The core object. Drives the Today tab and every reminder decision.
class StreakStatus extends Equatable {
  const StreakStatus({
    required this.current,
    required this.longest,
    required this.todayCount,
    required this.todayDate,
    required this.deadlineUtc,
    required this.checkedAt,
    this.lastContributionDate,
    this.previousStreak = 0,
    this.weekTotal = 0,
    this.monthTotal = 0,
    this.freshness = DataFreshness.fresh,
  });

  /// Consecutive days ending yesterday or today.
  ///
  /// Today counts toward this only once it has a contribution. A streak of 47
  /// with nothing yet today is still 47 and at risk — never 0. Getting this
  /// wrong makes the app feel broken every morning.
  final int current;

  final int longest;

  final int todayCount;

  /// GitHub's label for today, not a locally computed date.
  final String todayDate;

  /// When today's contribution window closes. Surfaced as a countdown rather
  /// than a wall-clock time, because "before midnight" is ambiguous in every
  /// timezone but UTC.
  final DateTime deadlineUtc;

  final DateTime checkedAt;
  final String? lastContributionDate;

  /// The run that just ended, when [current] is zero.
  ///
  /// Without it the app cannot tell someone who just lost twenty-three days
  /// apart from someone who installed it ten seconds ago — and PLAN.md
  /// section 10 calls that moment either the most valuable thing here or the
  /// reason someone uninstalls.
  final int previousStreak;

  final int weekTotal;
  final int monthTotal;
  final DataFreshness freshness;

  /// Nothing has counted yet today.
  bool get atRisk => todayCount == 0;

  bool get isSafeToday => todayCount > 0;

  /// Time remaining before the streak breaks. Clamped at zero.
  Duration remaining(DateTime now) {
    final left = deadlineUtc.difference(now.toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  /// True when the app cannot vouch for [todayCount].
  ///
  /// The UI uses this to hedge rather than to hide: an unverified zero still
  /// warrants a nudge, it just must not claim certainty.
  bool get isUncertain => freshness != DataFreshness.fresh;

  @override
  List<Object?> get props => [
    current,
    longest,
    todayCount,
    todayDate,
    deadlineUtc,
    checkedAt,
    lastContributionDate,
    previousStreak,
    weekTotal,
    monthTotal,
    freshness,
  ];
}
