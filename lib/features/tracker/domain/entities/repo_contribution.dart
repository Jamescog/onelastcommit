import 'package:equatable/equatable.dart';

/// A repository's share of the contributions in a period.
class RepoContribution extends Equatable {
  const RepoContribution({
    required this.name,
    required this.contributionCount,
    required this.lastActivityAt,
    this.uncountedPushes = 0,
    this.isPrivate = false,
    this.isFork = false,
    this.primaryLanguage,
  });

  /// Full "owner/name".
  final String name;

  final int contributionCount;
  final DateTime lastActivityAt;

  /// Work pushed here that earned no square. A fork will report every push
  /// as uncounted, which is usually the answer to "why did my streak break".
  final int uncountedPushes;

  final bool isPrivate;
  final bool isFork;
  final String? primaryLanguage;

  bool get hasUncountedWork => uncountedPushes > 0;

  @override
  List<Object?> get props => [
    name,
    contributionCount,
    lastActivityAt,
    uncountedPushes,
    isPrivate,
    isFork,
    primaryLanguage,
  ];
}
