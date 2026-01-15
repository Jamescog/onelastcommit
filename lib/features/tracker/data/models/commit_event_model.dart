import '../../domain/entities/commit_event.dart';

class CommitEventModel extends CommitEvent {
  const CommitEventModel({
    required super.id,
    required super.repoName,
    required super.commitCount,
    required super.occurredAt,
  });

  factory CommitEventModel.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>;
    final commits = payload['commits'] as List? ?? [];

    return CommitEventModel(
      id: json['id'],
      repoName: json['repo']['name'],
      commitCount: commits.length,
      occurredAt: DateTime.parse(json['created_at']),
    );
  }

  factory CommitEventModel.fromMap(Map<String, dynamic> map) {
    return CommitEventModel(
      id: map['event_id'],
      repoName: map['repo_name'],
      commitCount: map['commit_count'],
      occurredAt: DateTime.parse(map['occurred_at_utc']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'event_id': id,
      'repo_name': repoName,
      'commit_count': commitCount,
      'occurred_at_utc': occurredAt.toUtc().toIso8601String(),
    };
  }
}
