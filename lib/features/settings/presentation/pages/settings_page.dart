import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

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
          return _Loaded(settings: state.settings, schedule: state.schedule);
        },
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.settings, this.schedule});

  final AppSettings settings;
  final ScheduleOutcome? schedule;

  void _update(BuildContext context, AppSettings next) =>
      context.read<SettingsBloc>().add(UpdateSettings(next));

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _Account(login: settings.username),
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
        _ReminderTimes(settings: settings, schedule: schedule),
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
        const SizedBox(height: AppSpacing.xxl),
        const SectionHeader(title: 'Account'),
        const SizedBox(height: AppSpacing.md),
        const _SignOut(),

        const DevPanel(),
        const SizedBox(height: AppSpacing.massive),
      ],
    );
  }
}

class _Account extends StatelessWidget {
  const _Account({required this.login});

  /// The stored account. Known even when the profile is not: the profile row
  /// is only in the mirror once a sync has landed, so reading "Not connected"
  /// off a null profile told a signed-in user with an expired token — or one
  /// who simply had not synced yet — that they had no account at all.
  final String login;

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
                  profile?.initial ??
                      (login.isEmpty ? '·' : login[0].toUpperCase()),
                  style: text.titleMedium?.copyWith(color: t.onAccent),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.name ??
                          (login.isEmpty ? 'Not connected' : login),
                      style: text.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(switch ((profile, login.isEmpty)) {
                      (final p?, _) => '@${p.login}',
                      (null, true) =>
                        'Connect a GitHub account to start tracking',
                      (null, false) => 'Signed in — profile not fetched yet',
                    }, style: text.bodySmall?.copyWith(color: t.textSecondary)),
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

/// Sign out, and say plainly what it does and does not reach.
///
/// It does not revoke anything. GitHub's token-revocation endpoint
/// authenticates with the OAuth app's client secret, and a device-flow client
/// has none — that absence is the whole reason the device flow exists. So the
/// token is destroyed here and stays live on github.com until the user
/// withdraws it there, and pretending otherwise would be the same class of
/// lie as a false all-clear.
class _SignOut extends StatelessWidget {
  const _SignOut();

  static final _applications = Uri.parse(
    'https://github.com/settings/applications',
  );

  Future<void> _confirm(BuildContext context) async {
    final bloc = context.read<SettingsBloc>();
    final t = context.tokens;

    final leaving = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Sign out?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This phone forgets your token, cancels every reminder and '
              'deletes what One Last Commit recorded — saves, response '
              'times, the lot. Your contribution history is safe on GitHub; '
              'these numbers are not, because nothing else ever had them.',
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Signing out cannot revoke the token itself — that only '
              'happens on github.com.',
              style: Theme.of(
                dialog,
              ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () => launchUrl(
                _applications,
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Authorised apps on GitHub'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: t.danger),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    // The router redirects to onboarding the moment the cleared settings are
    // emitted, so there is nothing to navigate here.
    if (leaving ?? false) bloc.add(SignOut());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppCard(
      tone: AppTone.danger,
      onTap: () => _confirm(context),
      child: Row(
        children: [
          Icon(Icons.logout, size: 18, color: t.danger),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sign out',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: t.danger),
                ),
                const SizedBox(height: 2),
                Text(
                  'Removes the token and everything recorded on this device',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderTimes extends StatelessWidget {
  const _ReminderTimes({required this.settings, this.schedule});

  final AppSettings settings;
  final ScheduleOutcome? schedule;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final selected = settings.reminderTimes.toSet();

    // Anything stored but not offered still gets a chip. Setup and settings
    // used to publish different lists, so a time chosen in one was invisible
    // and unremovable in the other while going on firing.
    final choices = <String>{
      ...ReminderScheduler.offeredTimes,
      ...selected,
    }.toList()..sort();
    final dropped = schedule?.dropped.toSet() ?? const <String>{};

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('When', style: Theme.of(context).textTheme.titleSmall),
          if (!settings.remindersEnabled) ...[
            const SizedBox(height: 2),
            Text(
              'Turn "Remind me" on to change these.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final time in choices)
                FilterChip(
                  label: Text(time),
                  avatar: dropped.contains(time)
                      ? Icon(Icons.block, size: 16, color: t.warning)
                      : null,
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
          if (settings.remindersEnabled && selected.isEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _Note(
              // The switch above still reads "on". Without this the app went
              // quiet forever while claiming to be watching.
              text:
                  'No times selected, so no reminders will fire. Pick at '
                  'least one, or turn reminders off.',
              tone: AppTone.warning,
            ),
          ] else if (dropped.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _Note(
              text: dropped.length == 1
                  ? '${dropped.first} was not scheduled — there is not enough '
                        'of the UTC day left after it to act on a nudge.'
                  : '${dropped.join(", ")} were not scheduled — there is not '
                        'enough of the UTC day left after them to act on a '
                        'nudge.',
              tone: AppTone.warning,
            ),
          ],
          if (_cutsItClose(selected, settings.timezone)) ...[
            const SizedBox(height: AppSpacing.md),
            const _Note(
              text:
                  'Some of these fire under two hours before the day closes '
                  'in UTC — a tight window to save a streak in.',
              tone: AppTone.warning,
            ),
          ],
        ],
      ),
    );
  }

  /// True when a chosen time leaves little room before the next UTC midnight.
  /// The definition lives with the scheduler so warning and scheduling can
  /// never disagree about what "late" means.
  static bool _cutsItClose(Set<String> times, String zoneName) =>
      times.any((time) => ReminderScheduler.tooCloseToDeadline(time, zoneName));
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

/// A one-line caveat under a card's controls.
///
/// Every reason a reminder can fail to register used to be a silent
/// `continue` in the scheduler, so the screen went on describing reminders
/// that were never going to fire.
class _Note extends StatelessWidget {
  const _Note({required this.text, required this.tone});

  final String text;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = tone.resolve(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_outlined, size: 14, color: colors.foreground),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.foreground),
          ),
        ),
      ],
    );
  }
}
