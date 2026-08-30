import 'package:equatable/equatable.dart';

/// Why something did not work.
///
/// The subclasses exist so a caller can tell "we could not reach GitHub" from
/// "GitHub will not accept this token" from "there is nothing stored yet".
/// They used to collapse into two, and every one of them arrived at the UI as
/// the same silence.
abstract class Failure extends Equatable {
  const Failure(this.message);

  /// Safe to show a user as-is.
  final String message;

  @override
  List<Object?> get props => [message];
}

/// GitHub answered, but not with what was asked for.
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'GitHub could not answer that']);
}

/// The local mirror could not be read or written.
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Could not read local data']);
}

/// Nothing is stored yet. Not an error — a state.
///
/// Kept apart from [CacheFailure] because "no rows" and "the database threw"
/// were indistinguishable, and the difference is whether the app says
/// "fetch your history" or "something went wrong".
class EmptyMirrorFailure extends Failure {
  const EmptyMirrorFailure([super.message = 'Nothing fetched yet']);
}

/// No response at all. The cache is still valid; it just cannot be refreshed.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = "Couldn't reach GitHub"]);
}

/// The token is gone, expired beyond refresh, or revoked.
///
/// The one failure that the user cannot resolve by waiting, so it is the one
/// that has to reach the router rather than a banner.
class AuthFailure extends Failure {
  const AuthFailure([
    super.message = 'Your GitHub sign-in has expired',
  ]);
}

/// GitHub is throttling. Distinct from [ServerFailure] because it resolves on
/// its own, and telling someone to retry now would be wrong.
class RateLimitFailure extends Failure {
  const RateLimitFailure([super.message = 'GitHub is rate limiting us']);
}
