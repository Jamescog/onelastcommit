import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:olc/core/github/github_client.dart';
import 'package:olc/core/github/github_credentials.dart';
import 'package:olc/core/github/github_exceptions.dart';

/// A credentials store whose reads are answered here rather than by the
/// platform. The storage handle is never touched.
class _Creds extends GitHubCredentials {
  _Creds({required this.token, required this.expired})
    : super(storage: const FlutterSecureStorage());

  String? token;
  bool expired;

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<bool> needsRefresh({
    Duration margin = const Duration(minutes: 5),
  }) async => expired;
}

void main() {
  // GitHub's device-flow tokens expire in 28800s. Everything here is about
  // the eight-hour mark, which nothing exercised before: refreshIfNeeded was
  // correct code with no callers, and the client sent whatever was in storage.

  test(
    'a token near expiry is refreshed before the request goes out',
    () async {
      final creds = _Creds(token: 'stale', expired: true);
      final sent = <String>[];

      final client = GitHubClient(
        credentials: creds,
        client: MockClient((request) async {
          sent.add(request.headers['Authorization']!);
          return http.Response(jsonEncode({'data': <String, dynamic>{}}), 200);
        }),
      );
      client.refreshHandler = ({bool force = false}) async {
        creds
          ..token = 'fresh'
          ..expired = false;
        return true;
      };

      await client.query('query { viewer { login } }');

      expect(sent, ['Bearer fresh']);
    },
  );

  test('a live token is sent without a refresh', () async {
    final creds = _Creds(token: 'live', expired: false);
    var refreshes = 0;

    final client = GitHubClient(
      credentials: creds,
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode({'data': <String, dynamic>{}}), 200),
      ),
    );
    client.refreshHandler = ({bool force = false}) async {
      refreshes++;
      return true;
    };

    await client.query('query { viewer { login } }');

    expect(refreshes, 0);
  });

  test('a 401 forces one refresh and retries with the new token', () async {
    // A revoked grant is not near expiry — it is simply gone — so the expiry
    // check alone would never notice.
    final creds = _Creds(token: 'revoked', expired: false);
    final sent = <String>[];
    var forced = 0;

    final client = GitHubClient(
      credentials: creds,
      client: MockClient((request) async {
        sent.add(request.headers['Authorization']!);
        if (request.headers['Authorization'] == 'Bearer revoked') {
          return http.Response('{"message":"Bad credentials"}', 401);
        }
        return http.Response(jsonEncode({'data': <String, dynamic>{}}), 200);
      }),
    );
    client.refreshHandler = ({bool force = false}) async {
      if (force) forced++;
      creds.token = 'reissued';
      return true;
    };

    await client.query('query { viewer { login } }');

    expect(forced, 1);
    expect(sent, ['Bearer revoked', 'Bearer reissued']);
  });

  test(
    'a dead refresh token surfaces as unauthorized rather than retrying',
    () async {
      final creds = _Creds(token: 'revoked', expired: false);
      var attempts = 0;

      final client = GitHubClient(
        credentials: creds,
        client: MockClient((_) async {
          attempts++;
          return http.Response('{"message":"Bad credentials"}', 401);
        }),
      );
      client.refreshHandler = ({bool force = false}) async => false;

      await expectLater(
        client.query('query { viewer { login } }'),
        throwsA(isA<GitHubUnauthorized>()),
      );
      expect(attempts, 1, reason: 'a refusal to refresh must not be retried');
    },
  );

  test(
    'a refresh that succeeds but still 401s is not retried forever',
    () async {
      final creds = _Creds(token: 'cursed', expired: false);
      var attempts = 0;

      final client = GitHubClient(
        credentials: creds,
        client: MockClient((_) async {
          attempts++;
          return http.Response('{"message":"Bad credentials"}', 401);
        }),
      );
      client.refreshHandler = ({bool force = false}) async => true;

      await expectLater(
        client.query('query { viewer { login } }'),
        throwsA(isA<GitHubUnauthorized>()),
      );
      expect(attempts, 2, reason: 'one retry, then believe the answer');
    },
  );

  test('no token at all is unauthorized, not an empty request', () async {
    final client = GitHubClient(
      credentials: _Creds(token: null, expired: false),
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    await expectLater(
      client.query('query { viewer { login } }'),
      throwsA(isA<GitHubUnauthorized>()),
    );
  });
}
