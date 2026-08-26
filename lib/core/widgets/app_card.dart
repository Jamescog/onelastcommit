import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import 'app_tone.dart';

/// The app's one card shell.
///
/// Every panel in the app is this widget. Cards are flat and outlined rather
/// than elevated — on a dark ground a shadow reads as mud, and the border is
/// what separates a card from the surface behind it.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.tone,
    this.onTap,
    this.accentEdge = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// When set, the card takes the tone's tinted background and border. Use it
  /// for cards that carry state — at risk, saved — not for ordinary content.
  final AppTone? tone;

  final VoidCallback? onTap;

  /// Draws a 3px bar down the leading edge in the tone's colour. Only
  /// meaningful with [tone] set.
  final bool accentEdge;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tones = tone?.resolve(context);
    final radius = BorderRadius.circular(AppRadius.lg);

    // The accent edge is painted inside a Stack rather than as a Row child.
    // A Row with CrossAxisAlignment.stretch needs a bounded height, which it
    // never has inside a ListView — that threw during layout on every screen.
    // A non-uniform Border is not an option either: BoxDecoration rejects one
    // combined with a borderRadius.
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: tones?.background ?? t.surface,
        borderRadius: radius,
        border: Border.all(color: tones?.border ?? t.border),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // A transparent Material *inside* the decoration, so ListTiles
            // and other ink-splashing children paint onto the card's own
            // surface rather than searching past it for an ancestor.
            Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: accentEdge && tones != null
                    ? padding.add(const EdgeInsets.only(left: 3))
                    : padding,
                child: child,
              ),
            ),
            if (accentEdge && tones != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 3,
                child: ColoredBox(color: tones.foreground),
              ),
          ],
        ),
      ),
    );

    if (onTap == null) return decorated;

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: radius, child: decorated),
    );
  }
}
