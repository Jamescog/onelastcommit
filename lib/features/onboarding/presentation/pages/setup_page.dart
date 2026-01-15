import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../settings/domain/entities/app_settings.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../tracker/presentation/pages/home_page.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  String _selectedTimezone = DateTime.now().timeZoneName;
  final List<String> _selectedReminderTimes = ['20:00'];
  bool _trackWeekends = true;

  final List<String> _commonTimezones = [
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'America/Toronto',
    'Europe/London',
    'Europe/Paris',
    'Europe/Berlin',
    'Asia/Tokyo',
    'Asia/Shanghai',
    'Asia/Dubai',
    'Asia/Kolkata',
    'Australia/Sydney',
    'Pacific/Auckland',
    'UTC',
  ];

  final List<String> _availableTimes = [
    '08:00', '09:00', '10:00', '11:00', '12:00',
    '13:00', '14:00', '15:00', '16:00', '17:00',
    '18:00', '19:00', '20:00', '21:00', '22:00', '23:00',
  ];

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

  void _completeSetup() {
    final settings = AppSettings(
      username: 'demo_user',
      timezone: _selectedTimezone,
      remindersEnabled: true,
      reminderTimes: _selectedReminderTimes,
      trackWeekends: _trackWeekends,
      installedAt: DateTime.now(),
    );
    
    context.read<SettingsBloc>().add(UpdateSettings(settings));
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomePage()),
    );
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
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
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
                      ? AppColors.electricBlue
                      : AppColors.slateGray,
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
          const Icon(
            Icons.public,
            size: 80,
            color: AppColors.electricBlue,
          ),
          const SizedBox(height: 32),
          Text(
            'Select Your Timezone',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'We\'ll use this to send you reminders at the right time',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.slateGray,
                ),
          ),
          const SizedBox(height: 32),
          Card(
            child: Column(
              children: _commonTimezones.map((timezone) {
                final isSelected = timezone == _selectedTimezone;
                return ListTile(
                  title: Text(timezone.replaceAll('_', ' ')),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: AppColors.commitGreen)
                      : null,
                  selected: isSelected,
                  selectedTileColor: AppColors.commitGreen.withOpacity(0.1),
                  onTap: () => setState(() => _selectedTimezone = timezone),
                );
              }).toList(),
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
          const Icon(
            Icons.access_time,
            size: 80,
            color: AppColors.alertOrange,
          ),
          const SizedBox(height: 32),
          Text(
            'Set Reminder Times',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Choose when you want to be reminded to commit. Select one or more times.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.slateGray,
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
                selectedColor: AppColors.alertOrange.withOpacity(0.3),
                checkmarkColor: AppColors.alertOrange,
                backgroundColor: AppColors.cardBackground,
                side: BorderSide(
                  color: isSelected ? AppColors.alertOrange : AppColors.borderColor,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          if (_selectedReminderTimes.isNotEmpty)
            Card(
              color: AppColors.alertOrange.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.alertOrange),
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
          const Icon(
            Icons.tune,
            size: 80,
            color: AppColors.commitGreen,
          ),
          const SizedBox(height: 32),
          Text(
            'Final Touches',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Customize your tracking preferences',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.slateGray,
                ),
          ),
          const SizedBox(height: 32),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.weekend, color: AppColors.commitGreen),
                  title: const Text('Track Weekends'),
                  subtitle: const Text('Get reminders on Saturday and Sunday'),
                  value: _trackWeekends,
                  activeColor: AppColors.commitGreen,
                  onChanged: (val) => setState(() => _trackWeekends = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            color: AppColors.electricBlue.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.electricBlue),
                      const SizedBox(width: 12),
                      Text(
                        'Setup Summary',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryItem('Timezone', _selectedTimezone.replaceAll('_', ' ')),
                  _buildSummaryItem('Reminders', '${_selectedReminderTimes.length} time(s): ${_selectedReminderTimes.join(', ')}'),
                  _buildSummaryItem('Weekends', _trackWeekends ? 'Enabled' : 'Disabled'),
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
                    color: AppColors.slateGray,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigation() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderColor, width: 1),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _nextPage,
          child: Text(
            _currentPage == 2 ? 'Complete Setup' : 'Continue',
          ),
        ),
      ),
    );
  }
}
