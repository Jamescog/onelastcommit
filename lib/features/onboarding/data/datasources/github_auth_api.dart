import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/github/github_exceptions.dart';
import '../../domain/entities/device_code.dart';

/// The outcome of one poll during the device flow.
sealed class DevicePollResult {
  const DevicePollResult();
}

/// The user has not finished on github.com yet. Keep polling.
class DevicePending extends DevicePollResult {
  const DevicePending();
}

/// Polled too fast. GitHub adds five seconds to the required interval.
class DeviceSlowDown extends DevicePollResult {
  const DeviceSlowDown(this.interval);

  final int interval;
}

/// The device code ran out. Not an error — the user needs a fresh code.
class DeviceExpired extends DevicePollResult {
  const DeviceExpired();
}

/// The user pressed Cancel on github.com.
class DeviceDenied extends DevicePollResult {
  const DeviceDenied();
}

class DeviceAuthorized extends DevicePollResult {
  const DeviceAuthorized({
    required this.accessToken,
    required this.scope,
    this.refreshToken,
    this.expiresAt,
  });

  final String accessToken;
  final String scope;
  final String? refreshToken;
  final DateTime? expiresAt;
}

/// GitHub's OAuth device-flow endpoints.
///
/// These live on github.com, not api.github.com, and take no bearer token —
/// which is why they do not go through GitHubClient.
class GitHubAuthApi {
  const GitHubAuthApi({required this.client, required this.clientId});

  final http.Client client;

  /// Public by design. The device flow exists precisely so a client that
  /// cannot keep a secret does not need one.
  final String clientId;

  static const _deviceCodeUrl = 'https://github.com/login/device/code';
  static const _tokenUrl = 'https://github.com/login/oauth/access_token';

  /// Minimum for the contribution calendar to include private contributions.
  /// Notably not `repo`: this token cannot read source.
  static const scope = 'read:user';

  Future<DeviceCodeGrant> requestDeviceCode() async {
    final body = await _post(_deviceCodeUrl, {
      'client_id': clientId,
      'scope': scope,
    });

    final error = body['error'];
    if (error != null) {
      // The most common setup mistake: the flow is off in the app settings.
      if (error == 'device_flow_disabled') {
        throw const GitHubForbidden(
          'Device flow is not enabled for this OAuth app',
        );
      }
      throw GitHubBadResponse('$error: ${body['error_description']}');
    }

    return DeviceCodeGrant(
      userCode: body['user_code'] as String,
      verificationUri: body['verification_uri'] as String,
      expiresAt: DateTime.now().add(
        Duration(seconds: (body['expires_in'] as num?)?.toInt() ?? 900),
      ),
      interval: (body['interval'] as num?)?.toInt() ?? 5,
      deviceCode: body['device_code'] as String,
    );
  }

  Future<DevicePollResult> poll(DeviceCodeGrant grant) async {
    final body = await _post(_tokenUrl, {
      'client_id': clientId,
      'device_code': grant.deviceCode,
      'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
    });

    final error = body['error'];
    if (error != null) {
      return switch (error) {
        'authorization_pending' => const DevicePending(),
        'slow_down' => DeviceSlowDown(
          (body['interval'] as num?)?.toInt() ?? grant.interval + 5,
        ),
        'expired_token' => const DeviceExpired(),
        'access_denied' => const DeviceDenied(),
        _ => throw GitHubBadResponse('$error: ${body['error_description']}'),
      };
    }
    return _authorizedFrom(body);
  }

  /// Exchanges a refresh token for a new access token.
  ///
  /// Not optional for this app: GitHub returns `expires_in: 28800`, so a token
  /// dies after eight hours and every user would be signed out daily without
  /// this.
  Future<DeviceAuthorized> refresh(String refreshToken) async {
    final body = await _post(_tokenUrl, {
      'client_id': clientId,
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
    });

    final error = body['error'];
    if (error != null) {
      // A dead refresh token means the whole grant is gone — re-auth, not retry.
      throw GitHubUnauthorized('$error: ${body['error_description']}');
    }
    return _authorizedFrom(body);
  }

  static DeviceAuthorized _authorizedFrom(Map<String, dynamic> body) {
    final expiresIn = (body['expires_in'] as num?)?.toInt();
    return DeviceAuthorized(
      accessToken: body['access_token'] as String,
      scope: (body['scope'] as String?) ?? '',
      refreshToken: body['refresh_token'] as String?,
      expiresAt: expiresIn == null
          ? null
          : DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
    );
  }

  Future<Map<String, dynamic>> _post(
    String url,
    Map<String, String> fields,
  ) async {
    final http.Response response;
    try {
      response = await client.post(
        Uri.parse(url),
        // Without this GitHub answers in form-encoding, not JSON.
        headers: const {'Accept': 'application/json'},
        body: fields,
      );
    } catch (_) {
      throw const GitHubUnreachable();
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const GitHubBadResponse('Expected an object');
      }
      return decoded;
    } on FormatException {
      throw const GitHubBadResponse('Body was not JSON');
    }
  }
}
