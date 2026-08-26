import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/device_code.dart';
import '../../domain/repositories/auth_repository.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class StartDeviceFlow extends AuthEvent {
  const StartDeviceFlow();
}

class CancelDeviceFlow extends AuthEvent {
  const CancelDeviceFlow();
}

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthIdle extends AuthState {
  const AuthIdle();
}

class AuthRequestingCode extends AuthState {
  const AuthRequestingCode();
}

/// The code is on screen and we are polling. The user is on github.com.
class AuthAwaitingUser extends AuthState {
  const AuthAwaitingUser(this.grant);

  final DeviceCodeGrant grant;

  @override
  List<Object?> get props => [grant];
}

class AuthAuthorized extends AuthState {
  const AuthAuthorized(this.login);

  final String login;

  @override
  List<Object?> get props => [login];
}

/// The device code ran out. Distinct from a failure: nothing went wrong, the
/// user simply did not finish in time, and the fix is a fresh code.
class AuthExpired extends AuthState {
  const AuthExpired();
}

class AuthFailed extends AuthState {
  const AuthFailed(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required this.repository}) : super(const AuthIdle()) {
    on<StartDeviceFlow>(_onStart);
    on<CancelDeviceFlow>((_, emit) {
      _cancelled = true;
      emit(const AuthIdle());
    });
  }

  final AuthRepository repository;
  bool _cancelled = false;

  Future<void> _onStart(StartDeviceFlow event, Emitter<AuthState> emit) async {
    _cancelled = false;
    emit(const AuthRequestingCode());

    final grantResult = await repository.requestDeviceCode();
    final grant = grantResult.fold((_) => null, (g) => g);
    if (grant == null) {
      emit(const AuthFailed("Couldn't reach GitHub. Check your connection."));
      return;
    }

    emit(AuthAwaitingUser(grant));

    // Poll until authorised or the code expires. The repository owns the
    // interval; GitHub penalises polling faster than it asks for.
    while (!_cancelled) {
      if (DateTime.now().isAfter(grant.expiresAt)) {
        emit(const AuthExpired());
        return;
      }
      final result = await repository.pollForToken(grant);
      final login = result.fold((_) => null, (l) => l);
      if (login != null) {
        emit(AuthAuthorized(login));
        return;
      }
      await Future<void>.delayed(Duration(seconds: grant.interval));
    }
  }
}
