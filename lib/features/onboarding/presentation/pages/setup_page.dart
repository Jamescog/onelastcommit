import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/dev/dev_scenario.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/util/notification_service.dart';
import '../../../../core/util/reminder_scheduler.dart';
import '../../../../core/util/timezone_service.dart';
import '../../../../core/widgets/dev/dev_panel.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../injection_container.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../tracker/presentation/bloc/tracker_bloc.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Not DateTime.now().timeZoneName: that yields abbreviations like 'EAT',
  // which no zone database can resolve. The platform is asked for the real
  // identifier instead, and the user can override it.
  String _selectedTimezone = 'UTC';
  String? _detected;
  final List<String> _selectedReminderTimes = ['20:00'];
  bool _trackWeekends = true;

  @override
  void initState() {
    super.initState();
    _detectTimezone();
  }

  Future<void> _detectTimezone() async {
    final zone = await const TimezoneService().detect();
    if (zone == null || !mounted) return;
    setState(() {
      _detected = zone;
      // Only adopt it if the user has not already chosen something.
      if (_selectedTimezone == 'UTC') _selectedTimezone = zone;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeSetup();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeSetup() async {
    final settingsBloc = context.read<SettingsBloc>();
    final current = settingsBloc.state;
    if (current is! SettingsLoaded) return;

    // The one moment the OS notification prompt makes sense to the user:
    // they chose reminder times seconds ago. Only the notification dialog is
    // asked for here — the exact-alarm request routes through a full system
    // settings screen, which is too jarring mid-onboarding; the permission
    // card in Settings picks up anything still missing.
    await sl<NotificationService>().request(includeExactAlarms: false);
    if (!mounted) return;

    // installedAt is set once here, and only anchors the analysis era. It
    // never gates whether a contribution counts toward the streak.
    settingsBloc.add(
      UpdateSettings(
        current.settings.copyWith(
          timezone: _selectedTimezone,
          remindersEnabled: true,
          reminderTimes: _selectedReminderTimes,
          trackWeekends: _trackWeekends,
          installedAt: devToolsEnabled
              ? DateTime.now().subtract(
                  Duration(days: demoInstalledDaysAgo.value),
                )
              : DateTime.now(),
        ),
      ),
    );

    // The tracker bloc outlives every screen, so after a sign-out and a fresh
    // sign-in it is still holding whatever the last account left in memory.
    // Nothing else refetches between app starts.
    context.read<TrackerBloc>().add(const SyncTracker());

    // No context.go here. The redirect moves the app the moment the saved
    // settings are emitted; navigating by hand first ran the redirect against
    // the pre-update state, which still had installedAt null, and bounced
    // through onboarding on the way. Screens state intent, the router decides.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildTimezonePage(),
                  _buildReminderTimesPage(),
                  _buildPreferencesPage(),
                ],
              ),
            ),
            _buildNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            IconButton(
              tooltip: 'Back',
              icon: Icon(Icons.arrow_back, color: t.textPrimary),
              onPressed: _previousPage,
            )
          else
            const SizedBox(width: 48),
          Semantics(
            label: 'Step ${_currentPage + 1} of 3',
            child: Row(
              children: [
                for (var i = 0; i < 3; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs / 2,
                    ),
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i ? t.accent : t.border,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  /// One heading treatment for all three steps.
  ///
  /// The icons used to be 80px and painted per-page in info, danger and
  /// accent — an entire step rendered in the alarm colour, which is how you
  /// train someone to ignore it. They read as chrome now, at a size that does
  /// not compete with the control the step is actually about.
  Widget _stepHeading(IconData icon, String title, String subtitle) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                for (final c in t.brandGradient) c.withValues(alpha: 0.24),
              ],
            ),
          ),
          child: Icon(icon, size: 26, color: t.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(title, style: text.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(subtitle, style: text.bodyLarge?.copyWith(color: t.textSecondary)),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _buildTimezonePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeading(
            Icons.public,
            'Time zone',
            'Reminders fire on your clock. The streak still closes at '
                'midnight UTC.',
          ),
          AppCard(
            onTap: () async {
              final picked = await TimezonePicker.show(
                context,
                detected: _detected,
              );
              if (picked != null) {
                setState(() => _selectedTimezone = picked);
              }
            },
            child: Row(
              children: [
                Icon(
                  _detected == _selectedTimezone
                      ? Icons.my_location
                      : Icons.public,
                  size: 20,
                  color: context.tokens.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedTimezone.split('/').last.replaceAll('_', ' '),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _detected == _selectedTimezone
                            ? 'Detected on this device · '
                                  '${TimezoneService.offsetLabel(_selectedTimezone)}'
                            : '$_selectedTimezone · '
                                  '${TimezoneService.offsetLabel(_selectedTimezone)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.tokens.textSecondary),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Search over 400 zones if this is not right.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderTimesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeading(
            Icons.access_time,
            'Remind me',
            'Pick one or more. You can change these any time in settings.',
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              // The same list settings offers. They used to differ, and a
              // time chosen here that settings did not list became invisible
              // and unremovable there.
              for (final time in ReminderScheduler.offeredTimes)
                FilterChip(
                  label: Text(time),
                  selected: _selectedReminderTimes.contains(time),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _selectedReminderTimes
                        ..add(time)
                        ..sort();
                    } else if (_selectedReminderTimes.length > 1) {
                      _selectedReminderTimes.remove(time);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            tone: AppTone.info,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: context.tokens.info),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _selectedReminderTimes.length == 1
                        ? 'One reminder a day, at '
                              '${_selectedReminderTimes.single}.'
                        : '${_selectedReminderTimes.length} reminders a day, '
                              'at ${_selectedReminderTimes.join(", ")}.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          // The warning settings has always shown, on the screen where the
          // choice is actually made. Pick 23:00 at UTC+0 here and the nudge
          // arrives with an hour left; nothing used to say so until the night
          // it mattered.
          if (_cutsItClose) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  size: 14,
                  color: context.tokens.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Some of these fire under two hours before the day '
                    'closes in UTC — a tight window to save a streak in.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.tokens.warning,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Shared with the settings screen through the scheduler, so the warning
  /// and the scheduling can never disagree about what "late" means.
  bool get _cutsItClose => _selectedReminderTimes.any(
    (time) => ReminderScheduler.tooCloseToDeadline(time, _selectedTimezone),
  );

  Widget _buildPreferencesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeading(
            Icons.tune,
            'Last thing',
            'Both of these are changeable later.',
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              secondary: Icon(
                Icons.weekend_outlined,
                color: context.tokens.textSecondary,
              ),
              title: const Text('Remind me at weekends'),
              // Naming it plainly avoids the reading that weekend
              // contributions somehow do not count. They do.
              subtitle: const Text(
                'Weekend contributions always count either way',
              ),
              value: _trackWeekends,
              onChanged: (val) => setState(() => _trackWeekends = val),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'What you picked'),
                const SizedBox(height: AppSpacing.md),
                _summaryRow(
                  'Time zone',
                  _selectedTimezone.replaceAll('_', ' '),
                ),
                _summaryRow('Reminders', _selectedReminderTimes.join(', ')),
                _summaryRow(
                  'Weekends',
                  _trackWeekends ? 'Reminders on' : 'Quiet',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flexible rather than a fixed 100px: the label column used to clip
          // its own text as soon as the user scaled type up.
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            flex: 3,
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigation() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.tokens.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _nextPage,
          child: Text(_currentPage == 2 ? 'Complete setup' : 'Continue'),
        ),
      ),
    );
  }
}
