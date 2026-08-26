import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/presentation/pages/login_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/onboarding/presentation/pages/setup_page.dart';
import '../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/tracker/presentation/pages/home_page.dart';
import '../widgets/dev/component_gallery_page.dart';
import '../widgets/dev/scenario_preview_page.dart';

/// Route paths, named once so no screen hardcodes a string.
class Routes {
  const Routes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const setup = '/setup';
  static const home = '/home';
  static const settings = '/settings';
  static const gallery = '/dev/components';
  static const scenarios = '/dev/scenarios';
}

/// The app had two sources of truth for navigation: a landing widget that
/// picked a screen from settings state, and onboarding screens that also
/// pushReplaced their way forward. Either could win. Now the redirect below is
/// the only thing that decides, and screens only ever state intent.
GoRouter buildRouter(SettingsBloc settingsBloc) {
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: _BlocRefresh(settingsBloc.stream),
    redirect: (context, state) {
      final settings = settingsBloc.state;
      final here = state.matchedLocation;

      // Dev tools sit outside the flow so they stay reachable in any state.
      if (here.startsWith('/dev')) return null;

      // Settings have not loaded yet — hold on the splash rather than guessing
      // and bouncing the user between screens a frame later.
      if (settings is! SettingsLoaded) {
        return here == Routes.splash ? null : Routes.splash;
      }

      final needsSetup =
          settings.settings.username.isEmpty ||
          settings.settings.installedAt == null;

      if (needsSetup) {
        final inFlow =
            here == Routes.onboarding ||
            here == Routes.login ||
            here == Routes.setup;
        return inFlow ? null : Routes.onboarding;
      }

      // Set up already: never leave someone stranded on the splash or looking
      // at onboarding they have finished.
      if (here == Routes.splash ||
          here == Routes.onboarding ||
          here == Routes.login ||
          here == Routes.setup) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const _SplashPage()),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingPage(),
      ),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginPage()),
      GoRoute(path: Routes.setup, builder: (_, _) => const SetupPage()),
      GoRoute(path: Routes.home, builder: (_, _) => const HomePage()),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsPage()),
      if (kDebugMode) ...[
        GoRoute(
          path: Routes.gallery,
          builder: (_, _) => const ComponentGalleryPage(),
        ),
        GoRoute(
          path: Routes.scenarios,
          builder: (_, _) => const ScenarioPreviewPage(),
        ),
      ],
    ],
  );
}

/// Bridges a bloc stream to the [Listenable] GoRouter wants for redirects.
class _BlocRefresh extends ChangeNotifier {
  _BlocRefresh(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
