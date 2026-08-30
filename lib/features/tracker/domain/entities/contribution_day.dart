import 'package:equatable/equatable.dart';

/// One cell of the contribution graph.
///
/// [date] is GitHub's own label for the day, carried through verbatim rather
/// than re-derived from a timestamp. Contributions are stamped in UTC, and the
/// calendar is the authority on which day a contribution belongs to — see
/// PLAN.md section 2.
class ContributionDay extends Equatable {
  const ContributionDay({
    required this.date,
    required this.count,
    required this.level,
    this.firstContributionAt,
    this.lastContributionAt,
    this.uncountedPushes = 0,
  });

  /// Date-only, in GitHub's labelling. Never construct this from a local
  /// DateTime.now() — take it from the calendar response.
  final String date;

  final int count;

  /// 0–4, matching github.com's level scale.
  final int level;

  /// Wall-clock of the first and last contribution on this day. Sourced from
  /// the events feed rather than the calendar, so both are null for days
  /// outside the events window and thin for private-repo-heavy users.
  final DateTime? firstContributionAt;
  final DateTime? lastContributionAt;

  /// Pushes seen in the public events feed that went to a branch this
  /// repository does not count. The diagnostic no other tool shows — see
  /// PLAN.md section 1 — but a floor, never a total: private work never
  /// reaches the feed, and the feed is thin even for public work.
  final int uncountedPushes;

  bool get hasContributions => count > 0;

  /// True when work was pushed but none of it counted. The single most
  /// useful thing to surface to a user whose streak broke while they were
  /// committing every day.
  bool get hasUncountedWorkOnly => count == 0 && uncountedPushes > 0;

  @override
  List<Object?> get props => [
    date,
    count,
    level,
    firstContributionAt,
    lastContributionAt,
    uncountedPushes,
  ];
}
