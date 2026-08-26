/// Spacing scale. Every gap, pad and inset in the app comes from here, so
/// rhythm stays consistent across screens built at different times.
class AppSpacing {
  const AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 40.0;
  static const massive = 48.0;
}

/// Corner radii. Kept deliberately small in number — three sizes and a pill.
class AppRadius {
  const AppRadius._();

  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 14.0;
  static const pill = 999.0;
}
