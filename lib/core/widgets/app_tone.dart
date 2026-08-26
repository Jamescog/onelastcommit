import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// The semantic weight of a piece of UI.
///
/// Components take a tone rather than colours, so the mapping from meaning to
/// palette lives in exactly one place. [danger] is reserved for the at-risk and
/// streak-broken states — it is never decoration.
enum AppTone { neutral, accent, info, warning, danger }

/// The three colours a toned surface needs, resolved for the active theme.
@immutable
class ToneColors {
  const ToneColors({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;
}

extension AppToneResolver on AppTone {
  ToneColors resolve(BuildContext context) {
    final t = context.tokens;
    return switch (this) {
      AppTone.neutral => ToneColors(
        foreground: t.textSecondary,
        background: t.surfaceSubtle,
        border: t.border,
      ),
      AppTone.accent => ToneColors(
        foreground: t.accent,
        background: t.accentSubtle,
        border: t.accent.withValues(alpha: 0.35),
      ),
      AppTone.info => ToneColors(
        foreground: t.info,
        background: t.infoSubtle,
        border: t.info.withValues(alpha: 0.35),
      ),
      AppTone.warning => ToneColors(
        foreground: t.warning,
        background: t.warningSubtle,
        border: t.warning.withValues(alpha: 0.35),
      ),
      AppTone.danger => ToneColors(
        foreground: t.danger,
        background: t.dangerSubtle,
        border: t.danger.withValues(alpha: 0.35),
      ),
    };
  }
}
