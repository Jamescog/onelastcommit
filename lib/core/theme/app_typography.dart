import 'package:flutter/material.dart';

/// Type scale, deliberately colourless.
///
/// The previous theme baked a colour into every one of these styles, which is
/// what made a second theme impossible to add. Colour is applied once, per
/// theme, via `TextTheme.apply` in [AppTheme] — so a style is only ever about
/// size, weight and spacing.
class AppTypography {
  const AppTypography._();

  /// Tabular figures, for anywhere digits line up in a column or tick upward:
  /// streak counts, countdowns, stat tiles.
  static const tabularFigures = [FontFeature.tabularFigures()];

  static const textTheme = TextTheme(
    // Reserved for the single largest number on a screen — the streak count.
    displayLarge: TextStyle(
      fontSize: 44,
      fontWeight: FontWeight.w700,
      height: 1.1,
      letterSpacing: -1,
      fontFeatures: tabularFigures,
    ),
    displayMedium: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: -0.5,
      fontFeatures: tabularFigures,
    ),
    displaySmall: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: -0.25,
      fontFeatures: tabularFigures,
    ),

    headlineLarge: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
    headlineMedium: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    headlineSmall: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),

    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.4,
    ),

    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.45,
    ),

    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    // Uppercase eyebrows and axis labels — the letter-spacing is what keeps
    // them legible at this size.
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.3,
      letterSpacing: 0.6,
    ),
  );
}
