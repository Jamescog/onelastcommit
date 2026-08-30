import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A glyph reversed out of the logo's gradient, in a disc.
///
/// The one piece of chrome the three pre-app screens share — onboarding, the
/// sign-in, and each setup step. It is deliberately the only shape in the app
/// that carries the warm half of the palette: the gradient encodes nothing, so
/// it cannot be misread as a status the way an icon painted in `danger` or
/// `success` would be.
///
/// It replaces a disc drawn at 24% alpha with a [AppTokens.textPrimary] glyph
/// on top, which had the colour of the brand in it on paper and none of it on
/// screen — the wash measured close enough to the page behind it to read as
/// nothing, and the glyph came out the same grey as the body text.
class BrandMark extends StatelessWidget {
  const BrandMark({
    required this.icon,
    this.size = 56,
    this.variant = 0,
    super.key,
  });

  final IconData icon;

  /// Diameter. The glyph is drawn at 42% of it, which keeps it inside the
  /// band of the gradient that stays under 4.5:1 against [AppTokens.onBrand] —
  /// the orange corner alone measures 2.89:1, and no glyph pixel reaches it.
  final double size;

  /// Rotates the gradient a third of a turn per step, so a sequence of marks
  /// reads as one shape seen from several angles rather than several colours.
  final int variant;

  static const _alignments = [
    (Alignment.topLeft, Alignment.bottomRight),
    (Alignment.topRight, Alignment.bottomLeft),
    (Alignment.topCenter, Alignment.bottomCenter),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (begin, end) = _alignments[variant % _alignments.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: t.brandGradient,
        ),
      ),
      child: Icon(icon, size: size * 0.42, color: t.onBrand),
    );
  }
}
