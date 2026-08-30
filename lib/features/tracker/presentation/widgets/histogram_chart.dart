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
    this.label = 'Distribution',
    this.height = 110,
    this.highlightPeak = true,
    super.key,
  });

  final List<int> values;

  /// Label for a bucket. Return null to leave a bucket unlabelled — hour
  /// axes only want every sixth tick.
  final String? Function(int index) labelFor;

  /// What the buckets measure, for a reader who cannot see the bars.
  final String label;

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
    final peakLabel = labelFor(peak);

    return Semantics(
      label: label,
      value: peakLabel == null ? 'highest $max' : 'highest $max at $peakLabel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The doc comment has always said only the peak is labelled. It
          // labelled buckets and never a value, so the one number the reader
          // came for was the one number missing.
          if (highlightPeak) ...[
            Text(
              peakLabel == null ? '$max' : '$max at $peakLabel',
              style: text.labelSmall?.copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
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
                                  ? t.success
                                  : t.success.withValues(alpha: 0.35),
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
                    overflow: TextOverflow.clip,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
