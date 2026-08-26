import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data/mock_data.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/app_settings.dart';
import '../bloc/settings_bloc.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (state is SettingsLoaded) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildProfileCard(context),
                const SizedBox(height: 24),
                _buildSectionTitle(context, 'Account'),
                const SizedBox(height: 12),
                _buildAccountCard(context, state.settings),
                const SizedBox(height: 24),
                _buildSectionTitle(context, 'Notifications'),
                const SizedBox(height: 12),
                _buildNotificationsCard(context, state.settings),
                const SizedBox(height: 24),
                _buildSectionTitle(context, 'Tracking'),
                const SizedBox(height: 12),
                _buildTrackingCard(context, state.settings),
                const SizedBox(height: 24),
                _buildDangerZone(context),
              ],
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: context.tokens.accent,
              child: Text(
                MockUser.mockUser.username[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    MockUser.mockUser.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${MockUser.mockUser.username}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.tokens.info,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    MockUser.mockUser.bio,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(color: context.tokens.textSecondary),
    );
  }

  Widget _buildAccountCard(BuildContext context, AppSettings settings) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.account_circle, color: context.tokens.info),
            title: const Text('GitHub Username'),
            subtitle: Text(MockUser.mockUser.username),
            trailing: Icon(
              Icons.chevron_right,
              color: context.tokens.textSecondary,
            ),
            onTap: () {},
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.email, color: context.tokens.info),
            title: const Text('Email'),
            subtitle: const Text('james@example.com'),
            trailing: Icon(
              Icons.chevron_right,
              color: context.tokens.textSecondary,
            ),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsCard(BuildContext context, AppSettings settings) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(
              Icons.notifications_active,
              color: context.tokens.danger,
            ),
            title: const Text('Daily Reminders'),
            subtitle: const Text('Get reminded to commit every day'),
            value: settings.remindersEnabled,
            onChanged: (val) {
              context.read<SettingsBloc>().add(
                UpdateSettings(
                  AppSettings(
                    username: settings.username,
                    githubToken: settings.githubToken,
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
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.schedule, color: context.tokens.info),
            title: const Text('Reminder Times'),
            subtitle: Text(settings.reminderTimes.join(', ')),
            trailing: Icon(
              Icons.chevron_right,
              color: context.tokens.textSecondary,
            ),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingCard(BuildContext context, AppSettings settings) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(Icons.calendar_today, color: context.tokens.accent),
            title: const Text('Track Weekends'),
            subtitle: const Text('Include Saturday and Sunday'),
            value: settings.trackWeekends,
            onChanged: (val) {
              context.read<SettingsBloc>().add(
                UpdateSettings(
                  AppSettings(
                    username: settings.username,
                    githubToken: settings.githubToken,
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
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.language, color: context.tokens.info),
            title: const Text('Timezone'),
            subtitle: Text(settings.timezone),
            trailing: Icon(
              Icons.chevron_right,
              color: context.tokens.textSecondary,
            ),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone(BuildContext context) {
    return Card(
      color: context.tokens.danger.withValues(alpha: 0.1),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.logout, color: context.tokens.danger),
            title: const Text('Sign Out'),
            subtitle: const Text('Sign out of your account'),
            onTap: () {},
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.delete_forever, color: context.tokens.danger),
            title: const Text('Delete Account'),
            subtitle: const Text('Permanently delete all data'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
