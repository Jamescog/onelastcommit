import 'package:equatable/equatable.dart';

/// A pending GitHub device-flow authorisation.
///
/// The device flow is what the client-held-token architecture requires: the
/// web flow's code exchange needs a client secret, which would have to live on
/// a server. GitHub's device flow explicitly does not need one, so the token
/// can be obtained and kept entirely on the phone. See PLAN.md section 3.
class DeviceCodeGrant extends Equatable {
  const DeviceCodeGrant({
    required this.userCode,
    required this.verificationUri,
    required this.expiresAt,
    required this.interval,
  });

  /// The eight characters the user types on github.com.
  final String userCode;

  final String verificationUri;

  /// GitHub expires a device code after 900 seconds.
  final DateTime expiresAt;

  /// Minimum seconds between polls. GitHub returns `slow_down` and adds five
  /// seconds if this is ignored.
  final int interval;

  Duration remaining(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  @override
  List<Object?> get props => [userCode, verificationUri, expiresAt, interval];
}
