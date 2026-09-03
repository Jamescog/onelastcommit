import 'dart:convert';

import 'package:http/http.dart' as http;

import 'github_credentials.dart';
import 'github_exceptions.dart';

/// What is left of this hour's GraphQL budget.
///
/// Surfaced because the app polls on a schedule. A contributionsCollection
/// query costs about one point against 5,000 an hour, so this should never
/// bind — but a silent throttle would look exactly like a broken streak, so it
/// is measured rather than assumed.
class RateLimitStatus {
  const RateLimitStatus({this.remaining, this.limit, this.resetAt});

  final int? remaining;
  final int? limit;
  final DateTime? resetAt;

  bool get isNearlyExhausted =>
      remaining != null && limit != null && remaining! < limit! * 0.1;
}

/// Transport for both GitHub APIs.
///
/// It owns the auth header, error mapping and rate-limit accounting; it knows
/// nothing about contributions. Query construction and parsing live in the
/// data source, so a schema change touches one file.
class GitHubClient {
  GitHubClient({required this.client, required this.credentials});

  final http.Client client;
  final GitHubCredentials credentials;

  static const _graphql = 'https://api.github.com/graphql';

  RateLimitStatus _rateLimit = const RateLimitStatus();
  RateLimitStatus get rateLimit => _rateLimit;

  /// Overrides the stored token. Development only — it is how a PAT is used to
  /// verify a query before the device flow exists.
  String? debugTokenOverride;

  /// Swaps a spent token for a live one. Wired in the injection container,
  /// because the refresh needs this client to resolve a login and this client
  /// needs the refresh to hold a token — neither can construct the other.
  ///
  /// Without it the transport read whatever was in secure storage and sent it
  /// regardless. GitHub's device-flow tokens expire in eight hours, so every
  /// user was signed out for good after a working day: the 401 became a
  /// swallowed sync, the swallowed sync became a stale banner, and the router
  /// keyed on settings rather than credentials, so nothing ever offered a way
  /// back in.
  Future<bool> Function({bool force})? refreshHandler;

  Future<Map<String, String>> _headers() async {
    // Refreshed before it is spent rather than after it breaks — a token that
    // expires mid-request fails the request.
    if (debugTokenOverride == null && await credentials.needsRefresh()) {
      await refreshHandler?.call();
    }
    final token = debugTokenOverride ?? await credentials.readAccessToken();
    if (token == null || token.isEmpty) {
      throw const GitHubUnauthorized('No token stored');
    }
    return {
      // Bearer, not `token`: fine-grained tokens require it and classic ones
      // accept it, so there is no reason to send the older form.
      'Authorization': 'Bearer $token',
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'one-last-commit',
    };
  }

  /// Runs a GraphQL query and returns its `data` object.
  Future<Map<String, dynamic>> query(
    String document, {
    Map<String, dynamic> variables = const {},
  }) async {
    final response = await _send(
      () async => client.post(
        Uri.parse(_graphql),
        headers: {...await _headers(), 'Content-Type': 'application/json'},
        body: jsonEncode({'query': document, 'variables': variables}),
      ),
    );

    final body = _decode(response.body);

    // GraphQL reports failures inside a 200, so the status code alone is not
    // enough to call a query successful.
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      final message = first is Map ? '${first['message']}' : '$first';
      final type = first is Map ? '${first['type']}' : '';
      if (type == 'RATE_LIMITED') {
        throw GitHubRateLimited(resetAt: _rateLimit.resetAt, message: message);
      }
      throw GitHubBadResponse(message);
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw const GitHubBadResponse('Response carried no data');
    }
    return data;
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    bool allowRetry = true,
  }) async {
    final http.Response response;
    try {
      response = await request();
    } on GitHubException {
      rethrow;
    } catch (_) {
      // No response at all. Deliberately not folded in with a server error:
      // the cache is still valid here, it just cannot be refreshed.
      throw const GitHubUnreachable();
    }

    _rateLimit = _readRateLimit(response.headers);

    switch (response.statusCode) {
      case >= 200 && < 300:
      case 304:
        return response;
      case 401:
        // A token can be dead without being near expiry — a revoked grant, a
        // password change. One forced refresh, then believe it. The request
        // thunk rebuilds its own headers, so the retry carries the new token.
        final refresh = refreshHandler;
        if (allowRetry && debugTokenOverride == null && refresh != null) {
          if (await refresh(force: true)) {
            return _send(request, allowRetry: false);
          }
        }
        throw const GitHubUnauthorized();
      case 403:
      case 429:
        // 403 covers both "forbidden" and "rate limited"; only the headers
        // tell them apart.
        if (_rateLimit.remaining == 0 ||
            response.headers.containsKey('retry-after')) {
          throw GitHubRateLimited(resetAt: _rateLimit.resetAt);
        }
        throw GitHubForbidden(_messageFrom(response.body));
      default:
        throw GitHubBadResponse(
          'HTTP ${response.statusCode}: ${_messageFrom(response.body)}',
        );
    }
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const GitHubBadResponse('Expected an object');
      }
      return decoded;
    } on FormatException {
      throw const GitHubBadResponse('Body was not JSON');
    }
  }

  static String _messageFrom(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {
      // Fall through to the raw body.
    }
    return body.length > 200 ? '${body.substring(0, 200)}…' : body;
  }

  static RateLimitStatus _readRateLimit(Map<String, String> headers) {
    final reset = headers['x-ratelimit-reset'];
    return RateLimitStatus(
      remaining: int.tryParse(headers['x-ratelimit-remaining'] ?? ''),
      limit: int.tryParse(headers['x-ratelimit-limit'] ?? ''),
      resetAt: reset == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (int.tryParse(reset) ?? 0) * 1000,
              isUtc: true,
            ),
    );
  }
}
