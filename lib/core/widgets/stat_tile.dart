import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import 'app_tone.dart';

/// A single number with a label beneath it.
///
/// The value uses the display scale's tabular figures so a ticking countdown
/// or a changing streak does not shift the layout under the reader.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.value,
    required this.label,
    this.icon,
    this.tone = AppTone.neutral,
    this.emphasis = StatEmphasis.normal,
    super.key,
  });

  final String value;
  final String label;
  final IconData? icon;

  /// Colours the value and icon. [AppTone.neutral] leaves the value in primary
  /// text — the default, because a row of tiles all shouting reads as noise.
  final AppTone tone;

  final StatEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = tone.resolve(context);
    final valueColor = tone == AppTone.neutral ? t.textPrimary : c.foreground;

    final valueStyle = switch (emphasis) {
      StatEmphasis.hero => text.displayLarge,
      StatEmphasis.normal => text.displaySmall,
      StatEmphasis.compact => text.titleLarge,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: c.foreground),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(value, style: valueStyle?.copyWith(color: valueColor)),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: text.bodySmall?.copyWith(color: t.textSecondary)),
      ],
    );
  }
}

enum StatEmphasis {
  /// The one number a screen is about.
  hero,
  normal,
  compact,
}

/// An evenly divided row of [StatTile]s separated by hairlines.
class StatTileRow extends StatelessWidget {
  const StatTileRow({required this.tiles, super.key});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: VerticalDivider(width: 1, color: t.border),
              ),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}
