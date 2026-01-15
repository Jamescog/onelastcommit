import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/tracker_bloc.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    context.read<TrackerBloc>().add(RefreshTrackerData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commit Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: BlocBuilder<TrackerBloc, TrackerState>(
        builder: (context, state) {
          if (state is TrackerLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is TrackerLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<TrackerBloc>().add(RefreshTrackerData());
              },
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _ActivityStatus(hasActivity: state.hasActivityToday),
                  const SizedBox(height: 24),
                  const Text(
                    'History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...state.events.map(
                    (e) => ListTile(
                      title: Text(e.repoName),
                      subtitle: Text('\${e.commitCount} commits'),
                      trailing: Text(
                        DateFormat(
                          'yyyy-MM-dd HH:mm',
                        ).format(e.occurredAt.toLocal()),
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else if (state is TrackerError) {
            return Center(child: Text(state.message));
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ActivityStatus extends StatelessWidget {
  final bool hasActivity;
  const _ActivityStatus({required this.hasActivity});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: hasActivity ? Colors.green.shade100 : Colors.orange.shade100,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(
              hasActivity ? Icons.check_circle : Icons.warning_amber,
              size: 48,
              color: hasActivity ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 8),
            Text(
              hasActivity
                  ? 'Pushed today! Keep it up.'
                  : 'No public commits yet today 👀',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (!hasActivity) ...[
              const SizedBox(height: 4),
              const Text('Still time.'),
            ],
          ],
        ),
      ),
    );
  }
}
