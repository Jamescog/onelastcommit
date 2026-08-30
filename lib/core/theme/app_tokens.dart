import 'package:flutter/material.dart';

/// Raw palette. Private on purpose: nothing outside this file names a hex
/// value, so a colour can only enter the app through a semantic token below.
///
/// Direction is the launcher icon — a night-sky navy ground under a gradient
/// that runs orange at the fist, through plum, to blue at the forearm. Those
/// stops are sampled from `assets/logo.png` and they set the app's identity.
///
/// The one thing the logo does not get to decide is state. Its warm half sits
/// on top of [_Palette.darkWarning] and [_Palette.darkDanger], so an app that
/// said "you are safe today" in the logo's orange would be one hue-step from
/// its own alarm colour. So the logo's blue carries the interactive role, its
/// plum carries [AppTokens.info], its warm end is reserved for brand chrome
/// that never encodes state, and green stays exactly where it was — on
/// [AppTokens.success] and the contribution ramp, which matches github.com so
/// the grid reads against muscle memory.
class _Palette {
  const _Palette._();

  // Sampled from assets/logo.png.
  static const logoNavy = Color(0xFF1D1E26);
  static const logoOrange = Color(0xFFF76E40);
  static const logoPlum = Color(0xFF8C4C6C);
  static const logoBlue = Color(0xFF0E52A7);

  /// What the logo's mark is cut out of. White in both themes, because the
  /// gradient it sits on is the same in both themes.
  static const onBrand = Color(0xFFFFFFFF);

  // Dark
  static const darkGround = logoNavy;
  static const darkSurface = Color(0xFF23252F);
  static const darkSurfaceSubtle = Color(0xFF1F212B);
  static const darkBorder = Color(0xFF343846);
  static const darkBorderStrong = Color(0xFF454A5C);
  static const darkText = Color(0xFFD9DEE7);
  static const darkMuted = Color(0xFF8E96A6);
  static const darkAccent = Color(0xFF3B82D9);
  static const darkAccentSubtle = Color(0xFF15203A);

  /// Dark text on the accent, not white: white on [darkAccent] measures
  /// 3.90:1, under the 4.5:1 a 14px semibold button label needs. This is
  /// 4.85:1, and dark-on-colour is what GitHub's own dark primary buttons do.
  static const darkOnAccent = Color(0xFF0E1116);
  static const darkSuccess = Color(0xFF4C9A62);
  static const darkSuccessSubtle = Color(0xFF16241B);
  static const darkInfo = Color(0xFFA585C9);
  static const darkInfoSubtle = Color(0xFF221A2C);
  static const darkWarning = Color(0xFFC99A4E);
  static const darkWarningSubtle = Color(0xFF241E12);
  static const darkDanger = Color(0xFFD0685F);
  static const darkDangerSubtle = Color(0xFF261716);

  // Light
  static const lightGround = Color(0xFFFBFCFD);
  static const lightSurface = Color(0xFFEAEEF3);
  static const lightSurfaceSubtle = Color(0xFFF3F6F9);
  static const lightBorder = Color(0xFFBFC9D4);
  static const lightBorderStrong = Color(0xFF9AA6B4);
  static const lightText = Color(0xFF1A1F26);
  static const lightMuted = Color(0xFF5B6672);
  static const lightAccent = Color(0xFF2A5FA8);
  static const lightAccentSubtle = Color(0xFFE0EAF6);
  static const lightOnAccent = Color(0xFFFFFFFF);
  static const lightSuccess = Color(0xFF2F7D48);
  static const lightSuccessSubtle = Color(0xFFDCEDE3);
  static const lightInfo = Color(0xFF6B4A8F);
  static const lightInfoSubtle = Color(0xFFEDE6F4);
  static const lightWarning = Color(0xFF8A6420);
  static const lightWarningSubtle = Color(0xFFF7EFDD);
  static const lightDanger = Color(0xFFB0463C);
  static const lightDangerSubtle = Color(0xFFFAE8E6);
}

/// Semantic colour tokens, resolved per theme.
///
/// Widgets read these through `context.tokens` rather than reaching for
/// [ColorScheme] directly, because the app needs distinctions Material's
/// scheme does not model — a border that is not an outline, a subtle tint for
/// each status, and the five-step contribution ramp.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.ground,
    required this.surface,
    required this.surfaceSubtle,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentSubtle,
    required this.onAccent,
    required this.success,
    required this.successSubtle,
    required this.info,
    required this.infoSubtle,
    required this.warning,
    required this.warningSubtle,
    required this.danger,
    required this.dangerSubtle,
    required this.heatmap,
    required this.brandGradient,
    required this.onBrand,
  });

  /// Scaffold background.
  final Color ground;

  /// Cards and raised panels.
  final Color surface;

  /// A surface that sits between [ground] and [surface] — list rows, inset
  /// wells, anything that needs separation without reading as a card.
  final Color surfaceSubtle;

  final Color border;
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;

  /// The interactive colour: buttons, links, focus, selection. Sampled from
  /// the logo's forearm. It carries no state meaning — a blue button says
  /// "press me", never "you are safe".
  final Color accent;
  final Color accentSubtle;

  /// Label colour on a filled [accent] surface. Per-theme, because the dark
  /// accent is too light to carry white text.
  final Color onAccent;

  /// The streak is alive. Green, and the hue of the contribution [heatmap],
  /// which is why "today" and "at risk" must be distinguished by treatment —
  /// a ring or outline — rather than by fill colour.
  final Color success;
  final Color successSubtle;

  /// Neutral, non-urgent information. The logo's plum, chosen so the five
  /// tone foregrounds stay separable by hue as well as by lightness.
  final Color info;
  final Color infoSubtle;

  final Color warning;
  final Color warningSubtle;

  /// Reserved for the at-risk and streak-broken states. Not decoration.
  final Color danger;
  final Color dangerSubtle;

  /// Five-step contribution ramp, index 0 (no contributions) to 4 (most),
  /// matching the level scale on github.com.
  final List<Color> heatmap;

  /// The logo's gradient — orange, plum, blue. Brand chrome only: the splash,
  /// onboarding, the sign-in screen, the profile header. It is deliberately
  /// the one part of the palette with no semantic meaning attached, so it can
  /// never be mistaken for a status.
  final List<Color> brandGradient;

  /// The mark drawn on [brandGradient] — the counterpart to [onAccent], and
  /// identical in both themes for the same reason the gradient is. Every
  /// stop of the gradient is dark enough to reverse a glyph out of.
  final Color onBrand;

  static const _brand = [
    _Palette.logoOrange,
    _Palette.logoPlum,
    _Palette.logoBlue,
  ];

  static const dark = AppTokens(
    ground: _Palette.darkGround,
    surface: _Palette.darkSurface,
    surfaceSubtle: _Palette.darkSurfaceSubtle,
    border: _Palette.darkBorder,
    borderStrong: _Palette.darkBorderStrong,
    textPrimary: _Palette.darkText,
    textSecondary: _Palette.darkMuted,
    accent: _Palette.darkAccent,
    accentSubtle: _Palette.darkAccentSubtle,
    onAccent: _Palette.darkOnAccent,
    success: _Palette.darkSuccess,
    successSubtle: _Palette.darkSuccessSubtle,
    info: _Palette.darkInfo,
    infoSubtle: _Palette.darkInfoSubtle,
    warning: _Palette.darkWarning,
    warningSubtle: _Palette.darkWarningSubtle,
    danger: _Palette.darkDanger,
    dangerSubtle: _Palette.darkDangerSubtle,
    // Level 0 sits above the card, not below it: an empty day is a mark on
    // the grid, not a hole in it. At 1.41:1 against the surface it holds the
    // calendar's shape, which the old 1.01:1 did not.
    heatmap: [
      Color(0xFF383D4E),
      Color(0xFF1E3D2A),
      Color(0xFF2C6340),
      Color(0xFF3E8A57),
      Color(0xFF57B575),
    ],
    brandGradient: _brand,
    onBrand: _Palette.onBrand,
  );

  static const light = AppTokens(
    ground: _Palette.lightGround,
    surface: _Palette.lightSurface,
    surfaceSubtle: _Palette.lightSurfaceSubtle,
    border: _Palette.lightBorder,
    borderStrong: _Palette.lightBorderStrong,
    textPrimary: _Palette.lightText,
    textSecondary: _Palette.lightMuted,
    accent: _Palette.lightAccent,
    accentSubtle: _Palette.lightAccentSubtle,
    onAccent: _Palette.lightOnAccent,
    success: _Palette.lightSuccess,
    successSubtle: _Palette.lightSuccessSubtle,
    info: _Palette.lightInfo,
    infoSubtle: _Palette.lightInfoSubtle,
    warning: _Palette.lightWarning,
    warningSubtle: _Palette.lightWarningSubtle,
    danger: _Palette.lightDanger,
    dangerSubtle: _Palette.lightDangerSubtle,
    heatmap: [
      Color(0xFFC6D0DB),
      Color(0xFFC6E3CF),
      Color(0xFF92C7A5),
      Color(0xFF5AA379),
      Color(0xFF2F7D48),
    ],
    brandGradient: _brand,
    onBrand: _Palette.onBrand,
  );

  @override
  AppTokens copyWith({
    Color? ground,
    Color? surface,
    Color? surfaceSubtle,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? accentSubtle,
    Color? onAccent,
    Color? success,
    Color? successSubtle,
    Color? info,
    Color? infoSubtle,
    Color? warning,
    Color? warningSubtle,
    Color? danger,
    Color? dangerSubtle,
    List<Color>? heatmap,
    List<Color>? brandGradient,
    Color? onBrand,
  }) {
    return AppTokens(
      ground: ground ?? this.ground,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      successSubtle: successSubtle ?? this.successSubtle,
      info: info ?? this.info,
      infoSubtle: infoSubtle ?? this.infoSubtle,
      warning: warning ?? this.warning,
      warningSubtle: warningSubtle ?? this.warningSubtle,
      danger: danger ?? this.danger,
      dangerSubtle: dangerSubtle ?? this.dangerSubtle,
      heatmap: heatmap ?? this.heatmap,
      brandGradient: brandGradient ?? this.brandGradient,
      onBrand: onBrand ?? this.onBrand,
    );
  }

  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      ground: Color.lerp(ground, other.ground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSubtle: Color.lerp(successSubtle, other.successSubtle, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSubtle: Color.lerp(infoSubtle, other.infoSubtle, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSubtle: Color.lerp(warningSubtle, other.warningSubtle, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSubtle: Color.lerp(dangerSubtle, other.dangerSubtle, t)!,
      heatmap: [
        for (var i = 0; i < heatmap.length; i++)
          Color.lerp(heatmap[i], other.heatmap[i], t)!,
      ],
      brandGradient: [
        for (var i = 0; i < brandGradient.length; i++)
          Color.lerp(brandGradient[i], other.brandGradient[i], t)!,
      ],
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
    );
  }
}

extension AppTokensContext on BuildContext {
  /// Semantic colours for the active theme.
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
