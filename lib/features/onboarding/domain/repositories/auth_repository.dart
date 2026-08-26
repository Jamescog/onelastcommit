import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/device_code.dart';

abstract class AuthRepository {
  /// Ask GitHub for a device code. No client secret is involved.
  Future<Either<Failure, DeviceCodeGrant>> requestDeviceCode();

  /// Poll for authorisation. Resolves to the GitHub login once the user has
  /// entered the code. In Phase 2 this also stores the token in secure
  /// storage; the token is never sent anywhere else.
  Future<Either<Failure, String>> pollForToken(DeviceCodeGrant grant);
}
