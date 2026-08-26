// Still rendering from mock data. Rebuilt against TrackerBloc in commit 10.
import 'package:flutter/material.dart';

import '../../../../../core/data/mock_data.dart';
import '../../../../../core/theme/app_tokens.dart';

class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildContributionGrid(context),
        const SizedBox(height: 24),
        _buildStatsCards(context),
      ],
    );
  }

  Widget _buildContributionGrid(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contribution Activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _ContributionGraph(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(BuildContext context) {
    final stats = MockData.contributionStats;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'Total',
                '${stats['totalContributions']}',
                Icons.code,
                context.tokens.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                'This Month',
                '${stats['thisMonth']}',
                Icons.calendar_month,
                context.tokens.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'Current Streak',
                '${stats['currentStreak']} days',
                Icons.local_fire_department,
                context.tokens.danger,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                'Best Streak',
                '${stats['longestStreak']} days',
                Icons.emoji_events,
                context.tokens.accent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ContributionGraph extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final contributions = MockData.contributionMap;
    final sortedDates = contributions.keys.toList()..sort();
    final recentDates = sortedDates.reversed
        .take(91)
        .toList()
        .reversed
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = 13;
        final rows = 7;
        final cellSize = (constraints.maxWidth - (columns - 1) * 4) / columns;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: columns * cellSize + (columns - 1) * 4,
            height: rows * cellSize + (rows - 1) * 4,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              scrollDirection: Axis.horizontal,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: rows,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1,
              ),
              itemCount: recentDates.length,
              itemBuilder: (context, index) {
                final date = recentDates[index];
                final count = contributions[date] ?? 0;

                return Container(
                  decoration: BoxDecoration(
                    color: _getContributionColor(context, count),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Maps a day's contribution count onto the five-step ramp, matching the
  /// level scale on github.com.
  Color _getContributionColor(BuildContext context, int count) {
    final ramp = context.tokens.heatmap;
    if (count == 0) return ramp[0];
    if (count <= 2) return ramp[1];
    if (count <= 4) return ramp[2];
    if (count <= 7) return ramp[3];
    return ramp[4];
  }
}
