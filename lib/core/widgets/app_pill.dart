import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_tone.dart';

/// A small status chip.
///
/// Carries state that needs to read at a glance — "at risk", "3h left",
/// "counted" — in form as well as colour, so it survives a greyscale glance.
class AppPill extends StatelessWidget {
  const AppPill({
    required this.label,
    this.tone = AppTone.neutral,
    this.icon,
    this.filled = true,
    super.key,
  });

  final String label;
  final AppTone tone;
  final IconData? icon;

  /// Outlined rather than tinted. Use on an already-tinted surface, where a
  /// filled pill would disappear into its parent.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = tone.resolve(context);
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: filled ? c.background : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c.foreground),
            const SizedBox(width: AppSpacing.xs),
          ],
          // Constrained on purpose: a long label — a language name at a large
          // text scale, a branch name — inside a mainAxisSize.min Row
          // overflowed the card horizontally without this.
          Flexible(
            child: Text(
              label,
              style: text.labelSmall?.copyWith(color: c.foreground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
