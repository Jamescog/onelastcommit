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

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: tones?.background ?? t.surface,
        borderRadius: radius,
        border: Border.all(color: tones?.border ?? t.border),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (accentEdge && tones != null)
              Container(width: 3, color: tones.foreground),
            Expanded(
              child: Padding(padding: padding, child: child),
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
