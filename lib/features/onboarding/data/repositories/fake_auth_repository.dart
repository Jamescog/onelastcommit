import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/device_code.dart';
import '../../domain/repositories/auth_repository.dart';

/// Stands in for GitHub during Phase 1.
///
/// It reproduces the flow's shape — a code with a real expiry, a poll that
/// takes a few rounds to succeed — so the screen is built against the timing
/// it will actually face rather than an instant success.
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
        verificationUri: 'https://github.com/login/device',
        expiresAt: DateTime.now().add(const Duration(seconds: 900)),
        interval: 5,
      ),
    );
  }

  @override
  Future<Either<Failure, String>> pollForToken(DeviceCodeGrant grant) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (DateTime.now().isAfter(grant.expiresAt)) return Left(ServerFailure());
    _polls++;
    // Authorises on the third poll, so the waiting state is actually visible.
    if (_polls < 3) return Left(CacheFailure());
    return const Right('jamescog');
  }
}
