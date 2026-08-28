import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/device_code.dart';

/// The outcome of one poll.
///
/// A sealed result rather than Either, because "not yet" is the expected
/// answer most of the time and is not a failure. Squeezing it into a Failure
/// would make the caller unable to tell waiting from denial from expiry —
/// three states that need three different things on screen.
sealed class AuthPoll {
  const AuthPoll();
}

/// Still waiting for the user on github.com.
class AuthPending extends AuthPoll {
  const AuthPending({this.slowDownTo});

  /// Set when GitHub asked us to back off; the caller must use this interval
  /// instead of its own or it is penalised again.
  final int? slowDownTo;
}

class AuthGranted extends AuthPoll {
  const AuthGranted(this.login);

  final String login;
}

/// The code ran out. Not an error — the fix is a fresh code.
class AuthCodeExpired extends AuthPoll {
  const AuthCodeExpired();
}

/// The user pressed Cancel on github.com.
class AuthDenied extends AuthPoll {
  const AuthDenied();
}

class AuthPollFailed extends AuthPoll {
  const AuthPollFailed(this.message);

  final String message;
}

abstract class AuthRepository {
  /// Ask GitHub for a device code. No client secret is involved.
  Future<Either<Failure, DeviceCodeGrant>> requestDeviceCode();

  /// One poll. The caller owns the loop and its cancellation.
  Future<AuthPoll> pollForToken(DeviceCodeGrant grant);

  /// Swaps the refresh token for a fresh access token when the current one is
  /// near expiry. False means the grant is gone and the user must re-auth.
  Future<bool> refreshIfNeeded();

  Future<void> signOut();
}
