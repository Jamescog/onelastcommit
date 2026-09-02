import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/entities.dart';

/// One contribution in a list: what it was, where, and when.
class ActivityRow extends StatelessWidget {
  const ActivityRow({required this.activity, super.key});

  final ContributionActivity activity;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
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
                if (activity.hasDiffStats) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      if (activity.additions != null)
                        Text(
                          '+${activity.additions}',
                          style: text.bodySmall?.copyWith(color: t.success),
                        ),
                      if (activity.deletions != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '-${activity.deletions}',
                          style: text.bodySmall?.copyWith(color: t.danger),
                        ),
                      ],
                      if (activity.sha != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          activity.sha!,
                          style: text.bodySmall?.copyWith(
                            color: t.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                if (activity.type == ContributionType.commit &&
                    activity.count > 1) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppPill(
                    label: '${activity.count} commits',
                    icon: Icons.commit,
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
