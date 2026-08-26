// Still rendering from mock data. Rebuilt against TrackerBloc in commit 11.
import 'package:flutter/material.dart';

import '../../../../../core/data/mock_data.dart';
import '../../../../../core/theme/app_tokens.dart';

class ReposTab extends StatelessWidget {
  const ReposTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: MockData.repositories.length,
      itemBuilder: (context, index) {
        final repo = MockData.repositories[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.tokens.info.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.folder, color: context.tokens.info),
            ),
            title: Text(
              repo['name'] as String,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  repo['description'] as String,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: context.tokens.info,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      repo['language'] as String,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.star_border,
                      size: 14,
                      color: context.tokens.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${repo['stars']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.fork_right,
                      size: 14,
                      color: context.tokens.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${repo['forks']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
