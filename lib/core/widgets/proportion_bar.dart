import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';

/// A static share of a whole, drawn as a bar.
///
/// Not a [LinearProgressIndicator], which is what these used to be: a screen
/// reader announces one of those as a progress bar — "thirty-four percent,
/// busy" — and nothing here is in progress. It ranks at a glance and needs no
/// axis to do it, so the only thing it owes a non-visual reader is the number
/// it is drawing.
class ProportionBar extends StatelessWidget {
  const ProportionBar({
    required this.value,
    required this.label,
    this.color,
    this.height = 4,
    super.key,
  });

  /// 0–1. Clamped, because a count divided by a stale maximum can exceed it.
  final double value;

  /// What the bar is a share of, spoken rather than drawn.
  final String label;

  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final share = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);

    return Semantics(
      label: label,
      value: '${(share * 100).round()}%',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: t.surfaceSubtle)),
                FractionallySizedBox(
                  widthFactor: share,
                  child: ColoredBox(color: color ?? t.success),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
