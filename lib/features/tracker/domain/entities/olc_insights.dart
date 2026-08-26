import 'package:equatable/equatable.dart';

import 'contribution_activity.dart';

/// What became of a reminder.
enum ReminderOutcome {
  /// Sent while the day was empty, and the day ended with contributions.
  saved,

  /// Sent while the day was empty, and the day stayed empty.
  broken,

  /// The day already had contributions — no nudge was needed.
  alreadySafe,

  /// The outcome was never resolved, usually because the app was offline
  /// through the deadline.
  unknown,
}

/// One reminder and what happened next.
///
/// This is the part of the history that cannot be reconstructed. GitHub will
/// hand back any past day's contribution count, but it will never say that we
/// nudged at 20:30 and the user committed at 21:07 — that only exists because
/// it was written down when it happened. See PLAN.md section 4.
class ReminderEvent extends Equatable {
  const ReminderEvent({
    required this.id,
    required this.sentAt,
    required this.streakAtSend,
    required this.contributionsAtSend,
    required this.outcome,
    this.hoursLeft,
    this.outcomeAt,
  });

  /// Client-generated. There is no natural key, and a double flush would
  /// otherwise inflate the save count.
  final String id;

  final DateTime sentAt;
  final int streakAtSend;
  final int contributionsAtSend;
  final ReminderOutcome outcome;
  final int? hoursLeft;
  final DateTime? outcomeAt;

  /// How long the user took to respond. Null unless this reminder saved a day.
  Duration? get responseTime =>
      outcome == ReminderOutcome.saved && outcomeAt != null
      ? outcomeAt!.difference(sentAt)
      : null;

  @override
  List<Object?> get props => [
    id,
    sentAt,
    streakAtSend,
    contributionsAtSend,
    outcome,
    hoursLeft,
    outcomeAt,
  ];
}

/// A streak that ended while the app was watching.
class StreakBreak extends Equatable {
  const StreakBreak({
    required this.brokeOn,
    required this.lengthBefore,
    this.recoveredOn,
  });

  final String brokeOn;
  final int lengthBefore;
  final String? recoveredOn;

  bool get hasRecovered => recoveredOn != null;

  @override
  List<Object?> get props => [brokeOn, lengthBefore, recoveredOn];
}

/// Everything the analysis page renders, computed on the client from the local
/// mirror so it stays available and fresh offline.
class OlcInsights extends Equatable {
  const OlcInsights({
    required this.installedAt,
    required this.daysTracked,
    required this.daysWithContributions,
    required this.saves,
    required this.remindersSent,
    required this.composition,
    required this.hourHistogram,
    required this.weekdayHistogram,
    required this.rollingWeekAverage,
    this.closestCall,
    this.medianResponseTime,
    this.countedPushes = 0,
    this.uncountedPushes = 0,
    this.breaks = const [],
    this.longestStreakInEra = 0,
  });

  // --- Era header ---
  final DateTime installedAt;
  final int daysTracked;
  final int daysWithContributions;

  // --- Impact: the app justifying its own existence ---
  final int saves;
  final int remindersSent;

  /// Smallest margin between a contribution and its deadline.
  final Duration? closestCall;

  /// Median time from reminder sent to first contribution.
  final Duration? medianResponseTime;

  // --- Composition ---
  final Map<ContributionType, int> composition;
  final int countedPushes;
  final int uncountedPushes;

  // --- Rhythm ---
  /// 24 buckets, local time, index 0 = midnight.
  final List<int> hourHistogram;

  /// 7 buckets, index 0 = Monday.
  final List<int> weekdayHistogram;

  // --- Streak history and trend ---
  final List<StreakBreak> breaks;
  final int longestStreakInEra;

  /// Rolling seven-day contribution averages, oldest first.
  final List<double> rollingWeekAverage;

  double get consistency =>
      daysTracked == 0 ? 0 : daysWithContributions / daysTracked;

  /// Share of pushed work that earned no square.
  double get uncountedShare {
    final total = countedPushes + uncountedPushes;
    return total == 0 ? 0 : uncountedPushes / total;
  }

  /// The hour the user most often contributes in. Null before any data.
  int? get peakHour {
    if (hourHistogram.every((h) => h == 0)) return null;
    var best = 0;
    for (var i = 1; i < hourHistogram.length; i++) {
      if (hourHistogram[i] > hourHistogram[best]) best = i;
    }
    return best;
  }

  @override
  List<Object?> get props => [
    installedAt,
    daysTracked,
    daysWithContributions,
    saves,
    remindersSent,
    closestCall,
    medianResponseTime,
    composition,
    countedPushes,
    uncountedPushes,
    hourHistogram,
    weekdayHistogram,
    breaks,
    longestStreakInEra,
    rollingWeekAverage,
  ];
}
