import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/util/reminder_scheduler.dart';
import '../../../../core/util/timezone_service.dart';
import '../../../../core/widgets/dev/dev_panel.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../tracker/presentation/bloc/tracker_bloc.dart';
import '../../domain/entities/app_settings.dart';
import '../bloc/settings_bloc.dart';
import '../widgets/permission_notice.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (state is! SettingsLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          return _Loaded(settings: state.settings);
        },
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.settings});

  final AppSettings settings;

  void _update(BuildContext context, AppSettings next) =>
      context.read<SettingsBloc>().add(UpdateSettings(next));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const _Account(),
        const SizedBox(height: AppSpacing.xxl),

        const SectionHeader(title: 'Reminders'),
        const SizedBox(height: AppSpacing.md),
        const PermissionNotice(),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Remind me'),
                subtitle: const Text(
                  'A nudge when nothing has counted yet today',
                ),
                value: settings.remindersEnabled,
                onChanged: (v) =>
                    _update(context, settings.copyWith(remindersEnabled: v)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Remind me at weekends'),
                // The graph does not care what day it is; this only decides
                // whether the app stays quiet. Naming it plainly avoids the
                // reading that weekends somehow do not count.
                subtitle: const Text(
                  'Weekend contributions always count either way',
                ),
                value: settings.trackWeekends,
                onChanged: settings.remindersEnabled
                    ? (v) =>
                          _update(context, settings.copyWith(trackWeekends: v))
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _ReminderTimes(settings: settings),
        const SizedBox(height: AppSpacing.xxl),

        const SectionHeader(
          title: 'Time zone',
          subtitle:
              'Reminder times are local. The deadline is always UTC '
              'midnight.',
        ),
        const SizedBox(height: AppSpacing.md),
        _TimezoneCard(settings: settings),
        const SizedBox(height: AppSpacing.xxl),

        const SectionHeader(title: 'Appearance'),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {settings.themeMode},
            showSelectedIcon: false,
            onSelectionChanged: (s) =>
                _update(context, settings.copyWith(themeMode: s.first)),
          ),
        ),
        const DevPanel(),
        const SizedBox(height: AppSpacing.massive),
      ],
    );
  }
}

class _Account extends StatelessWidget {
  const _Account();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return BlocBuilder<TrackerBloc, TrackerState>(
      builder: (context, state) {
        final profile = state is TrackerLoaded ? state.profile : null;

        return AppCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: t.accent,
                child: Text(
                  profile?.initial ?? '·',
                  style: text.titleMedium?.copyWith(color: t.onAccent),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.name ?? 'Not connected',
                      style: text.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile == null
                          ? 'Connect a GitHub account to start tracking'
                          : '@${profile.login}',
                      style: text.bodySmall?.copyWith(color: t.textSecondary),
                    ),
                    if (profile != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${profile.followers} followers · '
                        '${profile.publicRepos} repos',
                        style: text.bodySmall?.copyWith(color: t.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReminderTimes extends StatelessWidget {
  const _ReminderTimes({required this.settings});

  final AppSettings settings;

  static const _choices = [
    '08:00',
    '10:00',
    '12:00',
    '14:00',
    '16:00',
    '18:00',
    '19:00',
    '20:00',
    '21:00',
    '22:00',
    '23:00',
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final selected = settings.reminderTimes.toSet();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('When', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final time in _choices)
                FilterChip(
                  label: Text(time),
                  selected: selected.contains(time),
                  onSelected: settings.remindersEnabled
                      ? (on) {
                          final next = {...selected};
                          on ? next.add(time) : next.remove(time);
                          context.read<SettingsBloc>().add(
                            UpdateSettings(
                              settings.copyWith(
                                reminderTimes: next.toList()..sort(),
                              ),
                            ),
                          );
                        }
                      : null,
                ),
            ],
          ),
          if (_cutsItClose(selected, settings.timezone)) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_outlined, size: 14, color: t.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Some of these fire under two hours before the day closes '
                    'in UTC — a tight window to save a streak in.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: t.warning),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// True when a chosen time leaves little room before the next UTC midnight.
  /// The definition lives with the scheduler so warning and scheduling can
  /// never disagree about what "late" means.
  static bool _cutsItClose(Set<String> times, String zoneName) => times.any(
    (time) => ReminderScheduler.tooCloseToDeadline(time, zoneName),
  );
}

class _TimezoneCard extends StatelessWidget {
  const _TimezoneCard({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final valid = _resolves(settings.timezone);

    return AppCard(
      tone: valid ? null : AppTone.warning,
      onTap: () async {
        final detected = await const TimezoneService().detect();
        if (!context.mounted) return;
        final picked = await TimezonePicker.show(context, detected: detected);
        if (picked != null && context.mounted) {
          context.read<SettingsBloc>().add(
            UpdateSettings(settings.copyWith(timezone: picked)),
          );
        }
      },
      child: Row(
        children: [
          Icon(
            valid ? Icons.public : Icons.warning_amber_outlined,
            size: 18,
            color: valid ? t.textSecondary : t.warning,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.timezone,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (valid)
                  Text(
                    'UTC${TimezoneService.offsetLabel(settings.timezone)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                  ),
                if (!valid) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Not a valid IANA identifier. Pick one from the list.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: t.warning),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: t.textSecondary),
        ],
      ),
    );
  }

  static bool _resolves(String name) {
    try {
      tz.getLocation(name);
      return true;
    } catch (_) {
      return false;
    }
  }
}
