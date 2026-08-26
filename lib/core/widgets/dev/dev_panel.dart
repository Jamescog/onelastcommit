import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/settings/domain/entities/app_settings.dart';
import '../../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../../features/tracker/presentation/bloc/tracker_bloc.dart';
import '../../dev/dev_scenario.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_tokens.dart';
import '../widgets.dart';
import 'component_gallery_page.dart';

/// Whether the on-device developer panel is compiled in.
///
/// `flutter build apk --dart-define=DEV=true`
///
/// Kept separate from kDebugMode so a release build can be handed to a phone
/// for review with the scenario switcher still reachable. It is off by
/// default, so a genuine release never carries it.
const bool devToolsEnabled = bool.fromEnvironment('DEV');

/// Scenario switching, from the phone.
///
/// Changing the scenario changes what the fake serves, but a normal sync will
/// not overwrite days it has already sealed — so this resets the mirror and
/// refetches rather than syncing.
class DevPanel extends StatelessWidget {
  const DevPanel({super.key});

  @override
  Widget build(BuildContext context) {
    if (!devToolsEnabled) return const SizedBox.shrink();
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        const SectionHeader(
          eyebrow: 'Not in a real release',
          title: 'Developer',
          subtitle:
              'The app runs on generated data until Phase 2 connects '
              'GitHub.',
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          tone: AppTone.info,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Scenario', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              ValueListenableBuilder<Scenario>(
                valueListenable: activeScenario,
                builder: (context, active, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final s in Scenario.values)
                          ChoiceChip(
                            label: Text(s.label),
                            selected: s == active,
                            onSelected: (_) {
                              activeScenario.value = s;
                              context.read<TrackerBloc>().add(
                                const ResetTracker(),
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      active.description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.history_toggle_off),
                title: const Text('Backdate install by 90 days'),
                // The analysis page counts only days since install, so a
                // fresh install has a one-day era and nothing to plot.
                subtitle: const Text('Gives the analysis page a real era'),
                onTap: () {
                  final state = context.read<SettingsBloc>().state;
                  if (state is! SettingsLoaded) return;
                  context.read<SettingsBloc>().add(
                    UpdateSettings(
                      state.settings.copyWith(
                        installedAt: DateTime.now().subtract(
                          Duration(days: demoInstalledDaysAgo.value),
                        ),
                      ),
                    ),
                  );
                  context.read<TrackerBloc>().add(const LoadTracker());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Install date backdated')),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Wipe and refetch'),
                onTap: () =>
                    context.read<TrackerBloc>().add(const ResetTracker()),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Replay onboarding'),
                // Clearing username and installedAt is all it takes: the
                // router's redirect is the single thing deciding where the
                // app opens, so it sends you back through the device flow.
                subtitle: const Text('Sign out and walk the auth flow again'),
                onTap: () {
                  final state = context.read<SettingsBloc>().state;
                  if (state is! SettingsLoaded) return;
                  final s = state.settings;
                  context.read<SettingsBloc>().add(
                    UpdateSettings(
                      AppSettings(
                        username: '',
                        timezone: s.timezone,
                        remindersEnabled: s.remindersEnabled,
                        reminderTimes: s.reminderTimes,
                        trackWeekends: s.trackWeekends,
                        themeMode: s.themeMode,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Component gallery'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ComponentGalleryPage(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
