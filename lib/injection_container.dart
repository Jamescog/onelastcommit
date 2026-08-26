import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/util/db_service.dart';
import 'core/util/notification_service.dart';
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

Future<void> init() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

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
    () => TrackerRepositoryImpl(remote: sl(), local: sl()),
  );
}
