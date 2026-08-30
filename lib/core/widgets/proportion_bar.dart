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
            width: double.infinity,
            child: Stack(
              children: [
                // The track is the card's own border colour, not
                // [surfaceSubtle]. A bar lives inside an AppCard, and
                // surfaceSubtle measures 1.07:1 against the light card and
                // 1.05:1 against the dark one — the same way the heatmap's
                // empty cell used to vanish. The unfilled remainder is the
                // bar's scale, so it has to survive being drawn on a surface.
                Positioned.fill(child: ColoredBox(color: t.border)),

                // Both layers are positioned, and both for the same reason:
                // a Stack hands its *un*positioned children loose
                // constraints, so the fill's ColoredBox took
                // `constraints.smallest` — zero height — and painted
                // nothing at all. Every bar in the app was drawing its track
                // and no fill. Positioned.fill is what makes the height
                // tight.
                //
                // centerStart, because FractionallySizedBox otherwise
                // centres the fraction: a 20% bar would have floated in the
                // middle of the track with a gap on either side.
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: share,
                    child: ColoredBox(color: color ?? t.success),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
