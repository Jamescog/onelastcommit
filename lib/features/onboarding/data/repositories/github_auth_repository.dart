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
  GitHubAuthRepository({
    required this.api,
    required this.credentials,
    required this.client,
  });

  final GitHubAuthApi api;
  final GitHubCredentials credentials;
  final GitHubClient client;

  /// A token GitHub has already issued, whose owner we have not resolved yet.
  ///
  /// A device code is single use. Once it has been exchanged, polling again
  /// returns an error and the grant is gone for good — so when it is the
  /// identity lookup that failed, the retry has to resume from here. Without
  /// this, a connection that dropped in the half-second between the token
  /// arriving and the viewer query going out reported "Couldn't connect",
  /// discarded a token the user had just approved, and sent them back for
  /// another code.
  DeviceAuthorized? _pendingIdentity;

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
    final pending = _pendingIdentity;
    if (pending != null) return _finish(pending);

    try {
      final result = await api.poll(grant);
      return switch (result) {
        DeviceAuthorized() => await _finish(result),
        DevicePending() => const AuthPending(),
        DeviceSlowDown(:final interval) => AuthPending(slowDownTo: interval),
        DeviceExpired() => const AuthCodeExpired(),
        DeviceDenied() => const AuthDenied(),
      };
    } on GitHubUnreachable catch (e) {
      // The user is on github.com and this app is behind a browser. A poll
      // that does not land is ordinary; the code outlives it.
      return AuthTransient(e.message);
    } on GitHubException catch (e) {
      return AuthPollFailed(e.message);
    }
  }

  /// Swaps the refresh token for a fresh access token.
  ///
  /// GitHub returns `expires_in: 28800`, so without this every user is signed
  /// out after eight hours.
  @override
  Future<bool> refreshIfNeeded({bool force = false}) async {
    if (!force && !await credentials.needsRefresh()) return true;
    final refreshToken = await credentials.readRefreshToken();
    if (refreshToken == null) return false;
    try {
      // The login is already known, so a refresh needs no viewer query — and
      // must not fail over one.
      await _save(
        await api.refresh(refreshToken),
        login: await credentials.readLogin() ?? '',
      );
      return true;
    } on GitHubUnauthorized {
      // A dead refresh token means the grant is gone. Clearing here keeps the
      // app from retrying a credential that can never work again.
      await credentials.clear();
      return false;
    } on GitHubException {
      // Anything else — no network, a rate limit — says nothing about the
      // token. Signing someone out over a dropped connection would be the
      // same mistake the device flow used to make.
      return false;
    }
  }

  @override
  Future<void> signOut() {
    _pendingIdentity = null;
    return credentials.clear();
  }

  /// Stores the token, then resolves the login it belongs to.
  ///
  /// The token is written before the lookup, so a failure here loses nothing
  /// that cannot be retried.
  Future<AuthPoll> _finish(DeviceAuthorized auth) async {
    _pendingIdentity = auth;
    await _save(auth, login: '');

    try {
      // The token response carries no identity, so the login comes from a
      // viewer query using the token we just stored.
      final data = await client.query('query { viewer { login } }');
      final login = (data['viewer'] as Map<String, dynamic>)['login'] as String;
      await _save(auth, login: login);
      _pendingIdentity = null;
      return AuthGranted(login);
    } on GitHubUnreachable catch (e) {
      return AuthTransient(e.message, afterGrant: true);
    } on GitHubException catch (e) {
      // The token itself is bad — a scope GitHub would not grant, a revoked
      // app. Keeping it would leave the app half signed in.
      _pendingIdentity = null;
      await credentials.clear();
      return AuthPollFailed(e.message);
    }
  }

  Future<void> _save(DeviceAuthorized auth, {required String login}) =>
      credentials.save(
        accessToken: auth.accessToken,
        login: login,
        refreshToken: auth.refreshToken,
        expiresAt: auth.expiresAt,
      );
}
