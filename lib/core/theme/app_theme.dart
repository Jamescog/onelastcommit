import 'package:flutter/material.dart';

import 'app_spacing.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(AppTokens.light, Brightness.light);

  static ThemeData get dark => _build(AppTokens.dark, Brightness.dark);

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: t.accent,
      onPrimary: t.onAccent,
      primaryContainer: t.accentSubtle,
      onPrimaryContainer: t.accent,
      secondary: t.info,
      onSecondary: t.onAccent,
      secondaryContainer: t.infoSubtle,
      onSecondaryContainer: t.info,
      surface: t.surface,
      onSurface: t.textPrimary,
      surfaceContainerLowest: t.ground,
      surfaceContainerLow: t.surfaceSubtle,
      surfaceContainerHighest: t.surface,
      onSurfaceVariant: t.textSecondary,
      outline: t.border,
      outlineVariant: t.borderStrong,
      error: t.danger,
      onError: t.onAccent,
      errorContainer: t.dangerSubtle,
      onErrorContainer: t.danger,
    );

    final textTheme = AppTypography.textTheme.apply(
      bodyColor: t.textPrimary,
      displayColor: t.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: [t],
      scaffoldBackgroundColor: t.ground,
      canvasColor: t.ground,
      textTheme: textTheme,
      dividerColor: t.border,

      cardTheme: CardThemeData(
        color: t.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: t.border),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: t.ground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: t.textPrimary),
        titleTextStyle: textTheme.titleLarge,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.onAccent,
          disabledBackgroundColor: t.surfaceSubtle,
          disabledForegroundColor: t.textSecondary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.textPrimary,
          side: BorderSide(color: t.borderStrong),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.info,
          textStyle: textTheme.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: t.accent, width: 2),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: t.textSecondary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: t.textSecondary),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: t.textPrimary,
        unselectedLabelColor: t.textSecondary,
        indicatorColor: t.accent,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: t.border,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.titleSmall,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: t.textSecondary,
        textColor: t.textPrimary,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: t.textSecondary,
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? t.onAccent
              : t.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? t.accent
              : t.surfaceSubtle,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? t.accent : t.border,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: t.surfaceSubtle,
        selectedColor: t.accentSubtle,
        side: BorderSide(color: t.border),
        labelStyle: textTheme.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),

      dividerTheme: DividerThemeData(color: t.border, space: 1, thickness: 1),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        linearTrackColor: t.surfaceSubtle,
        circularTrackColor: t.surfaceSubtle,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.surface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: t.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      iconTheme: IconThemeData(color: t.textSecondary),
    );
  }
}
