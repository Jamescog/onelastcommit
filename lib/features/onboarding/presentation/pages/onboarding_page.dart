import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../settings/domain/entities/app_settings.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _usernameController = TextEditingController();
  bool _trackWeekends = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to OLC')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Help developers stay consistent by tracking public GitHub pushes starting today.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'GitHub Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Track Weekends'),
              value: _trackWeekends,
              onChanged: (val) => setState(() => _trackWeekends = val),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final username = _usernameController.text.trim();
                  if (username.isNotEmpty) {
                    final settings = AppSettings(
                      username: username,
                      timezone: DateTime.now().timeZoneName,
                      remindersEnabled: true,
                      reminderTimes: const ['20:00', '22:00'],
                      trackWeekends: _trackWeekends,
                      installedAt: DateTime.now(),
                    );
                    context.read<SettingsBloc>().add(UpdateSettings(settings));
                  }
                },
                child: const Text('Get Started'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
