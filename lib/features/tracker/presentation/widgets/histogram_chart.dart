import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';

/// A bar histogram over a fixed set of buckets — hours of the day, days of the
/// week.
///
/// Sequential magnitude in a single hue. Bars are thin, anchored to the
/// baseline with rounded data-ends, and separated by a surface gap. Only the
/// peak is labelled: a number on every bar is noise, and the peak is the thing
/// the reader came for.
class HistogramChart extends StatelessWidget {
  const HistogramChart({
    required this.values,
    required this.labelFor,
    this.height = 110,
    this.highlightPeak = true,
    super.key,
  });

  final List<int> values;

  /// Label for a bucket. Return null to leave a bucket unlabelled — hour
  /// axes only want every sixth tick.
  final String? Function(int index) labelFor;

  final double height;
  final bool highlightPeak;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    if (values.isEmpty || values.every((v) => v == 0)) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Not enough data yet',
            style: text.bodySmall?.copyWith(color: t.textSecondary),
          ),
        ),
      );
    }

    final max = values.reduce((a, b) => a > b ? a : b);
    final peak = values.indexOf(max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Padding(
                    // A 2px surface gap keeps adjacent bars from reading as
                    // one mass.
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: max == 0
                            ? 0
                            : (values[i] / max).clamp(0.02, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: highlightPeak && i == peak
                                ? t.accent
                                : t.accent.withValues(alpha: 0.35),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: Text(
                  labelFor(i) ?? '',
                  textAlign: TextAlign.center,
                  style: text.labelSmall?.copyWith(
                    color: t.textSecondary,
                    letterSpacing: 0,
                  ),
                  maxLines: 1,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
