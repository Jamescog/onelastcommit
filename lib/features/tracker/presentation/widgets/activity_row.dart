import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/entities.dart';

/// One contribution in a list.
///
/// When something did not count, the row says so and names the branch. That
/// is the explanation for a streak that broke on a day full of work, and it is
/// the one thing no other GitHub client will tell you.
class ActivityRow extends StatelessWidget {
  const ActivityRow({required this.activity, super.key});

  final ContributionActivity activity;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      tone: activity.counted ? null : AppTone.warning,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: 16, color: t.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: text.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        activity.repoName,
                        style: text.bodySmall?.copyWith(color: t.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '  ·  ${_time(activity.occurredAt)}',
                      style: text.bodySmall?.copyWith(color: t.textSecondary),
                    ),
                  ],
                ),
                if (!activity.counted) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppPill(
                    label: activity.branch == null
                        ? "Didn't count"
                        : "Didn't count · ${activity.branch}",
                    tone: AppTone.warning,
                    icon: Icons.block,
                  ),
                ],
              ],
            ),
          ),
          if (activity.isPrivate)
            Icon(Icons.lock_outline, size: 14, color: t.textSecondary),
        ],
      ),
    );
  }

  IconData get _icon => switch (activity.type) {
    ContributionType.commit => Icons.commit,
    ContributionType.issue => Icons.error_outline,
    ContributionType.pullRequest => Icons.merge_type,
    ContributionType.review => Icons.rate_review_outlined,
  };

  String get _title {
    if (activity.title != null) return activity.title!;
    return switch (activity.type) {
      ContributionType.commit =>
        '${activity.count} ${activity.count == 1 ? "commit" : "commits"}',
      ContributionType.issue => 'Opened an issue',
      ContributionType.pullRequest => 'Opened a pull request',
      ContributionType.review => 'Reviewed a pull request',
    };
  }

  static String _time(DateTime at) {
    final local = at.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
