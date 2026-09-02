import 'package:equatable/equatable.dart';

/// The kinds of work that earn a square.
///
/// Commits are only one of them, which is why a push-event feed is the wrong
/// signal for this app — opening an issue or reviewing a pull request keeps a
/// streak alive without producing a single push.
enum ContributionType { commit, issue, pullRequest, review }

/// A single item in the day's activity list.
class ContributionActivity extends Equatable {
  const ContributionActivity({
    required this.id,
    required this.type,
    required this.repoName,
    required this.occurredAt,
    this.count = 1,
    this.title,
    this.isPrivate = false,
    this.sha,
    this.additions,
    this.deletions,
  });

  final String id;
  final ContributionType type;
  final String repoName;
  final DateTime occurredAt;

  /// For commit contributions, how many commits this entry represents.
  final int count;

  /// Issue or pull request title. Null for grouped commit contributions.
  final String? title;

  final bool isPrivate;

  /// Short commit hash, when this came from commit history.
  final String? sha;

  /// Lines added and removed. Available only for commits, and only in
  /// repositories the token can read.
  final int? additions;
  final int? deletions;

  bool get hasDiffStats => additions != null || deletions != null;

  @override
  List<Object?> get props => [
    id,
    type,
    repoName,
    occurredAt,
    count,
    title,
    isPrivate,
    sha,
    additions,
    deletions,
  ];
}
