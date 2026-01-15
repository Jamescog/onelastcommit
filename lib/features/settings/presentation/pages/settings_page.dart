import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/settings_bloc.dart';
import '../../domain/entities/app_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (state is SettingsLoaded) {
            final settings = state.settings;
            return ListView(
              children: [
                ListTile(
                  title: const Text('Username'),
                  subtitle: Text(settings.username),
                ),
                SwitchListTile(
                  title: const Text('Reminders'),
                  value: settings.remindersEnabled,
                  onChanged: (val) {
                    context.read<SettingsBloc>().add(
                      UpdateSettings(
                        AppSettings(
                          username: settings.username,
                          timezone: settings.timezone,
                          remindersEnabled: val,
                          reminderTimes: settings.reminderTimes,
                          trackWeekends: settings.trackWeekends,
                          installedAt: settings.installedAt,
                        ),
                      ),
                    );
                  },
                ),
                SwitchListTile(
                  title: const Text('Track Weekends'),
                  value: settings.trackWeekends,
                  onChanged: (val) {
                    context.read<SettingsBloc>().add(
                      UpdateSettings(
                        AppSettings(
                          username: settings.username,
                          timezone: settings.timezone,
                          remindersEnabled: settings.remindersEnabled,
                          reminderTimes: settings.reminderTimes,
                          trackWeekends: val,
                          installedAt: settings.installedAt,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
