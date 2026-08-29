import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/dev/dev_scenario.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/util/notification_service.dart';
import '../../../../core/util/timezone_service.dart';
import '../../../../core/widgets/dev/dev_panel.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../injection_container.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';

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

  final List<String> _availableTimes = [
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
    '21:00',
    '22:00',
    '23:00',
  ];

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

    context.go(Routes.home);
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            IconButton(
              icon: Icon(Icons.arrow_back, color: context.tokens.textPrimary),
              onPressed: _previousPage,
            )
          else
            const SizedBox(width: 48),
          Row(
            children: List.generate(
              3,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? context.tokens.info
                      : context.tokens.textSecondary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTimezonePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.public, size: 80, color: context.tokens.info),
          const SizedBox(height: 32),
          Text(
            'Select Your Timezone',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'We\'ll use this to send you reminders at the right time',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
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
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.access_time, size: 80, color: context.tokens.danger),
          const SizedBox(height: 32),
          Text(
            'Set Reminder Times',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Choose when you want to be reminded to commit. Select one or more times.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _availableTimes.map((time) {
              final isSelected = _selectedReminderTimes.contains(time);
              return FilterChip(
                label: Text(time),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedReminderTimes.add(time);
                      _selectedReminderTimes.sort();
                    } else {
                      if (_selectedReminderTimes.length > 1) {
                        _selectedReminderTimes.remove(time);
                      }
                    }
                  });
                },
                selectedColor: context.tokens.danger.withValues(alpha: 0.3),
                checkmarkColor: context.tokens.danger,
                backgroundColor: context.tokens.surface,
                side: BorderSide(
                  color: isSelected
                      ? context.tokens.danger
                      : context.tokens.border,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          if (_selectedReminderTimes.isNotEmpty)
            Card(
              color: context.tokens.danger.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: context.tokens.danger),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You\'ll receive ${_selectedReminderTimes.length} reminder${_selectedReminderTimes.length > 1 ? 's' : ''} daily',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreferencesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tune, size: 80, color: context.tokens.accent),
          const SizedBox(height: 32),
          Text(
            'Final Touches',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Customize your tracking preferences',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.weekend, color: context.tokens.accent),
                  title: const Text('Track Weekends'),
                  subtitle: const Text('Get reminders on Saturday and Sunday'),
                  value: _trackWeekends,
                  onChanged: (val) => setState(() => _trackWeekends = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            color: context.tokens.info.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: context.tokens.info),
                      const SizedBox(width: 12),
                      Text(
                        'Setup Summary',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryItem(
                    'Timezone',
                    _selectedTimezone.replaceAll('_', ' '),
                  ),
                  _buildSummaryItem(
                    'Reminders',
                    '${_selectedReminderTimes.length} time(s): ${_selectedReminderTimes.join(', ')}',
                  ),
                  _buildSummaryItem(
                    'Weekends',
                    _trackWeekends ? 'Enabled' : 'Disabled',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigation() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.tokens.border, width: 1)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _nextPage,
          child: Text(_currentPage == 2 ? 'Complete Setup' : 'Continue'),
        ),
      ),
    );
  }
}
