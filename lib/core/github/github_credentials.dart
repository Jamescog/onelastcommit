import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the GitHub token lives, and the only place it lives.
///
/// Under the client-held-token design the token never leaves the device: the
/// OLC server holds no GitHub credentials and cannot act as the user. It is
/// deliberately not in SharedPreferences, which is plain text on disk — that
/// was how the first version stored it.
class GitHubCredentials {
  const GitHubCredentials({required this.storage});

  final FlutterSecureStorage storage;

  static const _accessToken = 'gh_access_token';
  static const _refreshToken = 'gh_refresh_token';
  static const _expiresAt = 'gh_expires_at';
  static const _login = 'gh_login';

  Future<String?> readAccessToken() => storage.read(key: _accessToken);

  Future<String?> readRefreshToken() => storage.read(key: _refreshToken);

  Future<String?> readLogin() => storage.read(key: _login);

  Future<DateTime?> readExpiry() async {
    final raw = await storage.read(key: _expiresAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// True when the token is missing or within [margin] of expiring.
  ///
  /// The margin matters: a token that expires mid-request fails the request,
  /// so it is refreshed before it is spent rather than after it breaks.
  Future<bool> needsRefresh({
    Duration margin = const Duration(minutes: 5),
  }) async {
    if (await readAccessToken() == null) return true;
    final expiry = await readExpiry();
    if (expiry == null) return false; // Non-expiring token.
    return DateTime.now().toUtc().add(margin).isAfter(expiry);
  }

  Future<void> save({
    required String accessToken,
    required String login,
    String? refreshToken,
    DateTime? expiresAt,
  }) async {
    await storage.write(key: _accessToken, value: accessToken);
    await storage.write(key: _login, value: login);
    if (refreshToken != null) {
      await storage.write(key: _refreshToken, value: refreshToken);
    }
    if (expiresAt != null) {
      await storage.write(
        key: _expiresAt,
        value: expiresAt.toUtc().toIso8601String(),
      );
    }
  }

  Future<void> clear() async {
    for (final key in const [_accessToken, _refreshToken, _expiresAt, _login]) {
      await storage.delete(key: key);
    }
  }
}
