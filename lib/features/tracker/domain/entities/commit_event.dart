import 'package:equatable/equatable.dart';

class CommitEvent extends Equatable {
  final String id;
  final String repoName;
  final int commitCount;
  final DateTime occurredAt;

  const CommitEvent({
    required this.id,
    required this.repoName,
    required this.commitCount,
    required this.occurredAt,
  });

  @override
  List<Object?> get props => [id, repoName, commitCount, occurredAt];
}
