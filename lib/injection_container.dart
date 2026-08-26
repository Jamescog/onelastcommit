import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/util/db_service.dart';
import 'core/util/notification_service.dart';
import 'features/settings/data/datasources/settings_local_data_source.dart';
import 'features/settings/data/repositories/settings_repository_impl.dart';
import 'features/settings/domain/repositories/settings_repository.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/tracker/data/datasources/tracker_local_data_source.dart';
import 'features/tracker/data/datasources/tracker_remote_data_source.dart';
import 'features/tracker/data/repositories/tracker_repository_impl.dart';
import 'features/tracker/domain/repositories/tracker_repository.dart';
import 'features/tracker/presentation/bloc/tracker_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  sl.registerLazySingleton(() => http.Client());
  sl.registerLazySingleton(() => DatabaseService.instance);
  sl.registerLazySingleton(() => NotificationService());

  sl.registerFactory(() => SettingsBloc(repository: sl()));
  sl.registerFactory(() => TrackerBloc(repository: sl()));

  sl.registerLazySingleton<SettingsLocalDataSource>(
    () => SettingsLocalDataSourceImpl(sharedPreferences: sl()),
  );
  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(localDataSource: sl()),
  );

  sl.registerLazySingleton<TrackerRemoteDataSource>(
    () => TrackerRemoteDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<TrackerLocalDataSource>(
    () => TrackerLocalDataSourceImpl(
      sharedPreferences: sl(),
      databaseService: sl(),
    ),
  );
  sl.registerLazySingleton<TrackerRepository>(
    () => TrackerRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      settingsLocalDataSource: sl(),
    ),
  );
}
