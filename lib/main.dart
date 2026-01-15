import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'injection_container.dart' as di;
import 'core/util/notification_service.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'features/tracker/presentation/bloc/tracker_bloc.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';
import 'features/tracker/presentation/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  await di.sl<NotificationService>().init();
  runApp(const MyApp());
}

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
        title: 'OLC - GitHub Tracker',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
        home: const AppLanding(),
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
          if (state.settings.username.isEmpty) {
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
