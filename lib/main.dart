import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/util/notification_service.dart';
import 'core/widgets/dev/component_gallery_page.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/tracker/presentation/bloc/tracker_bloc.dart';
import 'injection_container.dart' as di;

/// Launch the component gallery instead of the app:
/// `flutter run --dart-define=GALLERY=true`
const bool _showGallery = bool.fromEnvironment('GALLERY');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  await di.sl<NotificationService>().init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Held for the app's lifetime: the router owns navigation state, and
  // rebuilding it would reset the stack on every settings change.
  late final SettingsBloc _settingsBloc = di.sl<SettingsBloc>()
    ..add(LoadSettings());
  late final _router = buildRouter(_settingsBloc);

  @override
  void dispose() {
    _settingsBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _settingsBloc),
        BlocProvider(
          create: (_) => di.sl<TrackerBloc>()..add(const SyncTracker()),
        ),
      ],
      child: _showGallery
          ? MaterialApp(
              title: 'OLC Components',
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              debugShowCheckedModeBanner: false,
              home: const ComponentGalleryPage(),
            )
          : MaterialApp.router(
              title: 'One Last Commit',
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              // Follows the device until the preference lands in settings.
              themeMode: ThemeMode.system,
              debugShowCheckedModeBanner: false,
              routerConfig: _router,
            ),
    );
  }
}
