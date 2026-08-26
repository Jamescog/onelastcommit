import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';

/// A titled section divider with an optional trailing action.
///
/// Replaces the hand-rolled Row + TextButton pairs that were repeated across
/// the tabs, so section rhythm stays identical everywhere.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.eyebrow,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Small uppercase label above the title. Use it to name a span of time or a
  /// data source — something the title itself should not have to carry.
  final String? eyebrow;

  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = context.tokens;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: text.labelSmall?.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              Text(title, style: text.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: text.bodySmall?.copyWith(color: t.textSecondary),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}
