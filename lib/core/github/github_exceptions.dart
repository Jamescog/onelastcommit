/// Failures the GitHub API produces, separated because the app must respond to
/// them differently.
///
/// Collapsing these into one error would be a real bug here: an expired token
/// needs a re-auth prompt, a rate limit needs a wait, and a network drop needs
/// cached data with a staleness marker. Rendering any of them as "no
/// contributions today" would tell someone their streak is safe when it may
/// not be.
sealed class GitHubException implements Exception {
  const GitHubException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// 401. The token is gone or revoked — the user must authorise again.
class GitHubUnauthorized extends GitHubException {
  const GitHubUnauthorized([super.message = 'GitHub rejected the token']);
}

/// 403 without a rate-limit reason, or a scope the token does not carry.
class GitHubForbidden extends GitHubException {
  const GitHubForbidden([super.message = 'Not permitted']);
}

/// Primary or secondary rate limit. [resetAt] is when it lifts.
class GitHubRateLimited extends GitHubException {
  const GitHubRateLimited({required this.resetAt, String? message})
    : super(message ?? 'Rate limited');

  final DateTime? resetAt;
}

/// The request never completed. Distinct from every server response.
class GitHubUnreachable extends GitHubException {
  const GitHubUnreachable([super.message = 'Could not reach GitHub']);
}

/// A 200 whose body carried GraphQL errors, or a shape we could not read.
class GitHubBadResponse extends GitHubException {
  const GitHubBadResponse([super.message = 'Unexpected response']);
}
