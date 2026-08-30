import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/util/build_identity.dart';
import 'core/util/notification_service.dart';
import 'core/widgets/dev/component_gallery_page.dart';
import 'features/onboarding/presentation/bloc/auth_bloc.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/tracker/presentation/bloc/tracker_bloc.dart';
import 'injection_container.dart' as di;

/// Launch the component gallery instead of the app:
/// `flutter run --dart-define=GALLERY=true`
const bool _showGallery = bool.fromEnvironment('GALLERY');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before anything reads the mirror: a build that parses differently must
  // not serve rows the previous build wrote.
  await BuildIdentity.resolve();
  await di.init();
  await di.sl<NotificationService>().init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // Held for the app's lifetime: the router owns navigation state, and
  // rebuilding it would reset the stack on every settings change.
  late final SettingsBloc _settingsBloc = di.sl<SettingsBloc>()
    ..add(LoadSettings());

  // Held for the same reason the observer below needs it: the reminder check
  // is an app-level concern, not something a screen owns.
  late final TrackerBloc _trackerBloc = di.sl<TrackerBloc>()
    ..add(const SyncTracker());

  late final _router = buildRouter(_settingsBloc);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _trackerBloc.close();
    _settingsBloc.close();
    super.dispose();
  }

  /// The app is never running when its own reminder fires — the OS delivers
  /// it, which is the point of scheduling in advance. Coming back to the
  /// foreground is the first moment we can notice one went out and ask the
  /// calendar what became of it.
  ///
  /// Phase 3's periodic background check calls the same repository method
  /// this dispatches to, so the two paths cannot drift.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _trackerBloc.add(const CheckReminders());
    }
  }

  /// Falls back to the device setting until settings have loaded.
  static ThemeMode _mode(SettingsState s) =>
      s is SettingsLoaded ? s.settings.themeMode : ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _settingsBloc),
        BlocProvider(create: (_) => di.sl<AuthBloc>()),
        BlocProvider.value(value: _trackerBloc),
      ],
      child: _showGallery
          ? MaterialApp(
              title: 'OLC Components',
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              debugShowCheckedModeBanner: false,
              home: const ComponentGalleryPage(),
            )
          : BlocListener<TrackerBloc, TrackerState>(
              // The one failure a user cannot wait out. A token that can no
              // longer be refreshed leaves the app reading a mirror it can
              // never update, and the router keys on settings rather than on
              // credentials — so without this the app sat on stale data
              // forever, showing a small "couldn't check" banner and offering
              // no way back to a sign-in screen.
              listenWhen: (a, b) => b is TrackerUnauthorized,
              listener: (context, _) =>
                  context.read<SettingsBloc>().add(SignOut()),
              child: BlocBuilder<SettingsBloc, SettingsState>(
                buildWhen: (a, b) => _mode(a) != _mode(b),
                builder: (context, state) => MaterialApp.router(
                  title: 'One Last Commit',
                  theme: AppTheme.light,
                  darkTheme: AppTheme.dark,
                  themeMode: _mode(state),
                  debugShowCheckedModeBanner: false,
                  routerConfig: _router,
                ),
              ),
            ),
    );
  }
}
