import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
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
          if (_afterDeadline(selected, settings.timezone)) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_outlined, size: 14, color: t.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  // A reminder after the UTC deadline can never help. At
                  // UTC+13 a 22:00 local nudge lands eleven hours too late.
                  child: Text(
                    'Some of these fall after the day has already closed in '
                    'UTC, so they cannot save a streak.',
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

  /// True when a chosen local time lands after that day's UTC midnight.
  static bool _afterDeadline(Set<String> times, String zoneName) {
    try {
      final zone = tz.getLocation(zoneName);
      final now = tz.TZDateTime.now(zone);
      for (final time in times) {
        final parts = time.split(':');
        final at = tz.TZDateTime(
          zone,
          now.year,
          now.month,
          now.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        final deadline = DateTime.utc(
          at.toUtc().year,
          at.toUtc().month,
          at.toUtc().day,
        ).add(const Duration(days: 1));
        if (at.toUtc().isAfter(deadline)) return true;
        // Same wall day in the zone but already the next UTC day.
        if (at.toUtc().day != at.day) return true;
      }
    } catch (_) {
      // An unresolvable zone is reported by the picker, not here.
    }
    return false;
  }
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
        final picked = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _TimezonePicker(),
        );
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

/// Searchable list of real IANA zones.
///
/// The previous build offered fifteen hardcoded cities and defaulted to
/// DateTime.now().timeZoneName, which yields abbreviations like "EAT" that no
/// zone database can resolve.
class _TimezonePicker extends StatefulWidget {
  const _TimezonePicker();

  @override
  State<_TimezonePicker> createState() => _TimezonePickerState();
}

class _TimezonePickerState extends State<_TimezonePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = tz.timeZoneDatabase.locations.keys.toList()..sort();
    final matches = _query.isEmpty
        ? all
        : all
              .where((z) => z.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search zones',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: matches.length,
              itemBuilder: (context, i) => ListTile(
                title: Text(matches[i]),
                onTap: () => Navigator.of(context).pop(matches[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
