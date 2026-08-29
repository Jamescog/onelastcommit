import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/github/github_client.dart';
import 'core/github/github_credentials.dart';
import 'core/util/db_service.dart';
import 'core/util/notification_service.dart';
import 'core/util/reminder_scheduler.dart';
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
import 'features/tracker/data/datasources/github_tracker_data_source.dart';
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

/// Serves generated scenarios instead of GitHub: `--dart-define=FAKE_DATA=true`.
/// The dev panel's scenario switcher only does anything under this flag.
const useFakeData = bool.fromEnvironment('FAKE_DATA');

Future<void> init() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  sl.registerLazySingleton(http.Client.new);
  sl.registerLazySingleton(() => const FlutterSecureStorage());
  sl.registerLazySingleton(() => GitHubCredentials(storage: sl()));
  sl.registerLazySingleton(() => GitHubClient(client: sl(), credentials: sl()));
  sl.registerLazySingleton(() => DatabaseService.instance);
  sl.registerLazySingleton(() => NotificationService());
  sl.registerLazySingleton(() => ReminderScheduler(notifications: sl()));

  sl.registerFactory(() => SettingsBloc(repository: sl(), scheduler: sl()));
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

  // Real GitHub data by default. The fake stays available for UI review and
  // for driving the scenario switcher: --dart-define=FAKE_DATA=true
  sl.registerLazySingleton<TrackerDataSource>(
    () => useFakeData
        ? const FakeTrackerDataSource()
        : GitHubTrackerDataSource(client: sl()),
  );
  sl.registerLazySingleton<TrackerLocalDataSource>(
    () => TrackerLocalDataSourceImpl(databaseService: sl()),
  );
  sl.registerLazySingleton<TrackerRepository>(
    () => TrackerRepositoryImpl(remote: sl(), local: sl(), settings: sl()),
  );
}
