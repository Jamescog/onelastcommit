import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_theme.dart';
import 'core/util/notification_service.dart';
import 'core/widgets/dev/component_gallery_page.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/tracker/presentation/bloc/tracker_bloc.dart';
import 'features/tracker/presentation/pages/home_page.dart';
import 'injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  await di.sl<NotificationService>().init();
  runApp(const MyApp());
}

/// Launch the component gallery instead of the app:
/// `flutter run --dart-define=GALLERY=true`
const bool _showGallery = bool.fromEnvironment('GALLERY');

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<SettingsBloc>()..add(LoadSettings())),
        BlocProvider(create: (_) => di.sl<TrackerBloc>()),
      ],
      child: MaterialApp(
        title: 'OLC - One Last Commit',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        // Follows the device until the theme preference lands in settings.
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: _showGallery ? const ComponentGalleryPage() : const AppLanding(),
      ),
    );
  }
}

class AppLanding extends StatelessWidget {
  const AppLanding({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        if (state is SettingsLoaded) {
          if (state.settings.username.isEmpty ||
              state.settings.installedAt == null) {
            return const OnboardingPage();
          } else {
            return const HomePage();
          }
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
