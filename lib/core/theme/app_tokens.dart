import 'package:flutter/material.dart';

/// Raw palette. Private on purpose: nothing outside this file names a hex
/// value, so a colour can only enter the app through a semantic token below.
///
/// Direction is "Refined GitHub" — recognisably in GitHub's family so the
/// contribution heatmap reads against muscle memory, but de-neoned, with a
/// warmer ground and a green that is muted rather than acid.
class _Palette {
  const _Palette._();

  // Dark
  static const darkGround = Color(0xFF12151A);
  static const darkSurface = Color(0xFF1A1F26);
  static const darkSurfaceSubtle = Color(0xFF161A21);
  static const darkBorder = Color(0xFF2C333D);
  static const darkBorderStrong = Color(0xFF3B434E);
  static const darkText = Color(0xFFD4DAE2);
  static const darkMuted = Color(0xFF8A93A0);
  static const darkAccent = Color(0xFF4C9A62);
  static const darkAccentSubtle = Color(0xFF16241B);
  static const darkInfo = Color(0xFF5E9BD6);
  static const darkInfoSubtle = Color(0xFF14202B);
  static const darkWarning = Color(0xFFC99A4E);
  static const darkWarningSubtle = Color(0xFF241E12);
  static const darkDanger = Color(0xFFD0685F);
  static const darkDangerSubtle = Color(0xFF261716);

  // Light
  static const lightGround = Color(0xFFFAFBFC);
  static const lightSurface = Color(0xFFF0F3F6);
  static const lightSurfaceSubtle = Color(0xFFF5F7F9);
  static const lightBorder = Color(0xFFD5DCE3);
  static const lightBorderStrong = Color(0xFFB9C3CD);
  static const lightText = Color(0xFF1A1F26);
  static const lightMuted = Color(0xFF5B6672);
  static const lightAccent = Color(0xFF2F7D48);
  static const lightAccentSubtle = Color(0xFFE4F1E9);
  static const lightInfo = Color(0xFF2C6DA8);
  static const lightInfoSubtle = Color(0xFFE1ECF6);
  static const lightWarning = Color(0xFF8A6420);
  static const lightWarningSubtle = Color(0xFFF7EFDD);
  static const lightDanger = Color(0xFFB0463C);
  static const lightDangerSubtle = Color(0xFFFAE8E6);

  static const onAccent = Color(0xFFFFFFFF);
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
    required this.info,
    required this.infoSubtle,
    required this.warning,
    required this.warningSubtle,
    required this.danger,
    required this.dangerSubtle,
    required this.heatmap,
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

  /// The brand accent. Also the hue of the contribution [heatmap], which is
  /// why "today" and "at risk" must be distinguished by treatment — a ring or
  /// outline — rather than by fill colour.
  final Color accent;
  final Color accentSubtle;
  final Color onAccent;

  /// Secondary interactive colour: links, tabs, non-destructive actions.
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
    onAccent: _Palette.onAccent,
    info: _Palette.darkInfo,
    infoSubtle: _Palette.darkInfoSubtle,
    warning: _Palette.darkWarning,
    warningSubtle: _Palette.darkWarningSubtle,
    danger: _Palette.darkDanger,
    dangerSubtle: _Palette.darkDangerSubtle,
    heatmap: [
      Color(0xFF1B2027),
      Color(0xFF1E3D2A),
      Color(0xFF2C6340),
      Color(0xFF3E8A57),
      Color(0xFF57B575),
    ],
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
    onAccent: _Palette.onAccent,
    info: _Palette.lightInfo,
    infoSubtle: _Palette.lightInfoSubtle,
    warning: _Palette.lightWarning,
    warningSubtle: _Palette.lightWarningSubtle,
    danger: _Palette.lightDanger,
    dangerSubtle: _Palette.lightDangerSubtle,
    heatmap: [
      Color(0xFFE8EBEE),
      Color(0xFFC6E3CF),
      Color(0xFF92C7A5),
      Color(0xFF5AA379),
      Color(0xFF2F7D48),
    ],
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
    Color? info,
    Color? infoSubtle,
    Color? warning,
    Color? warningSubtle,
    Color? danger,
    Color? dangerSubtle,
    List<Color>? heatmap,
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
      info: info ?? this.info,
      infoSubtle: infoSubtle ?? this.infoSubtle,
      warning: warning ?? this.warning,
      warningSubtle: warningSubtle ?? this.warningSubtle,
      danger: danger ?? this.danger,
      dangerSubtle: dangerSubtle ?? this.dangerSubtle,
      heatmap: heatmap ?? this.heatmap,
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
    );
  }
}

extension AppTokensContext on BuildContext {
  /// Semantic colours for the active theme.
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
