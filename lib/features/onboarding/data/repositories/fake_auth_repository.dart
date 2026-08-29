import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/device_code.dart';
import '../../domain/repositories/auth_repository.dart';

/// Stands in for GitHub when the app runs on generated data.
///
/// It reproduces the flow's timing rather than succeeding instantly — a code
/// with a real expiry, and authorisation only on the third poll — so the
/// waiting state is visible while building against it.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository();

  int _polls = 0;

  @override
  Future<Either<Failure, DeviceCodeGrant>> requestDeviceCode() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _polls = 0;
    return Right(
      DeviceCodeGrant(
        userCode: 'WDJB-MJHT',
        deviceCode: 'fake-device-code',
        verificationUri: 'https://github.com/login/device',
        expiresAt: DateTime.now().add(const Duration(seconds: 900)),
        interval: 5,
      ),
    );
  }

  @override
  Future<AuthPoll> pollForToken(DeviceCodeGrant grant) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (DateTime.now().isAfter(grant.expiresAt)) {
      return const AuthCodeExpired();
    }
    _polls++;
    return _polls < 3 ? const AuthPending() : const AuthGranted('jamescog');
  }

  @override
  Future<bool> refreshIfNeeded() async => true;

  @override
  Future<void> signOut() async {}
}
