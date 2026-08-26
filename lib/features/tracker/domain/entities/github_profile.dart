import 'package:equatable/equatable.dart';

class GitHubProfile extends Equatable {
  const GitHubProfile({
    required this.login,
    required this.name,
    this.avatarUrl,
    this.bio,
    this.location,
    this.followers = 0,
    this.following = 0,
    this.publicRepos = 0,
  });

  final String login;
  final String name;
  final String? avatarUrl;
  final String? bio;
  final String? location;
  final int followers;
  final int following;
  final int publicRepos;

  /// Fallback for the avatar when no image is available.
  String get initial =>
      login.isEmpty ? '?' : login.substring(0, 1).toUpperCase();

  @override
  List<Object?> get props => [
    login,
    name,
    avatarUrl,
    bio,
    location,
    followers,
    following,
    publicRepos,
  ];
}
