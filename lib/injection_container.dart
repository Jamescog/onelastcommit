import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/github/github_client.dart';
import 'core/github/github_credentials.dart';
import 'core/util/db_service.dart';
import 'core/util/notification_service.dart';
import 'features/onboarding/data/datasources/github_auth_api.dart';
import 'features/onboarding/data/repositories/fake_auth_repository.dart';
import 'features/onboarding/data/repositories/github_auth_repository.dart';
import 'features/onboarding/domain/repositories/auth_repository.dart';
import 'features/onboarding/presentation/bloc/auth_bloc.dart';
import 'features/settings/data/datasources/settings_local_data_source.dart';
import 'features/settings/data/repositories/settings_repository_impl.dart';
import 'features/settings/domain/repositories/settings_repository.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/tracker/data/datasources/fake_tracker_data_source.dart';
import 'features/tracker/data/datasources/tracker_data_source.dart';
import 'features/tracker/data/datasources/tracker_local_data_source.dart';
import 'features/tracker/data/repositories/tracker_repository_impl.dart';
import 'features/tracker/domain/repositories/tracker_repository.dart';
import 'features/tracker/presentation/bloc/tracker_bloc.dart';

final sl = GetIt.instance;

/// The OAuth app the device flow authorises against.
const githubClientId = String.fromEnvironment(
  'GITHUB_CLIENT_ID',
  defaultValue: 'Ov23licyi3BfdyGCbAoP',
);

/// Keeps the scripted auth flow for UI review: `--dart-define=FAKE_AUTH=true`.
const useFakeAuth = bool.fromEnvironment('FAKE_AUTH');

Future<void> init() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  sl.registerLazySingleton(http.Client.new);
  sl.registerLazySingleton(() => const FlutterSecureStorage());
  sl.registerLazySingleton(() => GitHubCredentials(storage: sl()));
  sl.registerLazySingleton(() => GitHubClient(client: sl(), credentials: sl()));
  sl.registerLazySingleton(() => DatabaseService.instance);
  sl.registerLazySingleton(() => NotificationService());

  sl.registerFactory(() => SettingsBloc(repository: sl()));
  sl.registerFactory(() => AuthBloc(repository: sl()));
  sl.registerFactory(() => TrackerBloc(repository: sl()));

  // The client id is public: the device flow exists so a client that cannot
  // keep a secret does not need one. Override per build with
  // --dart-define=GITHUB_CLIENT_ID=...
  sl.registerLazySingleton(
    () => GitHubAuthApi(client: sl(), clientId: githubClientId),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => useFakeAuth
        ? FakeAuthRepository()
        : GitHubAuthRepository(api: sl(), credentials: sl(), client: sl()),
  );
  sl.registerLazySingleton<SettingsLocalDataSource>(
    () => SettingsLocalDataSourceImpl(sharedPreferences: sl()),
  );
  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(localDataSource: sl()),
  );

  // Phase 1 runs entirely on the fake — there is no real source yet, so this
  // is registered in every build, not just debug. Phase 2 swaps it for the
  // GitHub-backed one: same interface, no other change.
  sl.registerLazySingleton<TrackerDataSource>(
    () => const FakeTrackerDataSource(),
  );
  sl.registerLazySingleton<TrackerLocalDataSource>(
    () => TrackerLocalDataSourceImpl(databaseService: sl()),
  );
  sl.registerLazySingleton<TrackerRepository>(
    () => TrackerRepositoryImpl(remote: sl(), local: sl(), settings: sl()),
  );
}
