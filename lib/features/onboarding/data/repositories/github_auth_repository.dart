import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/github/github_client.dart';
import '../../../../core/github/github_credentials.dart';
import '../../../../core/github/github_exceptions.dart';
import '../../domain/entities/device_code.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/github_auth_api.dart';

/// The real device flow.
///
/// One poll per call, so the bloc owns the loop and its cancellation rather
/// than blocking inside the repository.
class GitHubAuthRepository implements AuthRepository {
  const GitHubAuthRepository({
    required this.api,
    required this.credentials,
    required this.client,
  });

  final GitHubAuthApi api;
  final GitHubCredentials credentials;
  final GitHubClient client;

  @override
  Future<Either<Failure, DeviceCodeGrant>> requestDeviceCode() async {
    try {
      return Right(await api.requestDeviceCode());
    } on GitHubException {
      return Left(ServerFailure());
    }
  }

  @override
  Future<AuthPoll> pollForToken(DeviceCodeGrant grant) async {
    try {
      final result = await api.poll(grant);
      return switch (result) {
        DeviceAuthorized() => AuthGranted(await _persist(result)),
        DevicePending() => const AuthPending(),
        DeviceSlowDown(:final interval) => AuthPending(slowDownTo: interval),
        DeviceExpired() => const AuthCodeExpired(),
        DeviceDenied() => const AuthDenied(),
      };
    } on GitHubException catch (e) {
      return AuthPollFailed(e.message);
    }
  }

  /// Swaps the refresh token for a fresh access token.
  ///
  /// GitHub returns `expires_in: 28800`, so without this every user is signed
  /// out after eight hours.
  @override
  Future<bool> refreshIfNeeded() async {
    if (!await credentials.needsRefresh()) return true;
    final refreshToken = await credentials.readRefreshToken();
    if (refreshToken == null) return false;
    try {
      await _persist(await api.refresh(refreshToken));
      return true;
    } on GitHubException {
      // A dead refresh token means the grant is gone. Clearing here keeps the
      // app from retrying a credential that can never work again.
      await credentials.clear();
      return false;
    }
  }

  @override
  Future<void> signOut() => credentials.clear();

  /// Stores the token, then resolves the login it belongs to.
  Future<String> _persist(DeviceAuthorized auth) async {
    await credentials.save(
      accessToken: auth.accessToken,
      login: '',
      refreshToken: auth.refreshToken,
      expiresAt: auth.expiresAt,
    );

    // The token response carries no identity, so the login comes from a
    // viewer query using the token we just stored.
    final data = await client.query('query { viewer { login } }');
    final login = (data['viewer'] as Map<String, dynamic>)['login'] as String;

    await credentials.save(
      accessToken: auth.accessToken,
      login: login,
      refreshToken: auth.refreshToken,
      expiresAt: auth.expiresAt,
    );
    return login;
  }
}
