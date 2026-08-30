import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olc/core/theme/app_tokens.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  // These are the pairs the design actually depends on. They are asserted
  // rather than eyeballed because the last palette shipped a primary button
  // at 3.44:1 — white on the old green — and nothing caught it.
  for (final entry in {'dark': AppTokens.dark, 'light': AppTokens.light}.entries) {
    final name = entry.key;
    final t = entry.value;

    group('$name theme', () {
      test('body text clears AA on both ground and surface', () {
        expect(_contrast(t.textPrimary, t.ground), greaterThanOrEqualTo(4.5));
        expect(_contrast(t.textPrimary, t.surface), greaterThanOrEqualTo(4.5));
      });

      test('secondary text clears AA', () {
        expect(_contrast(t.textSecondary, t.ground), greaterThanOrEqualTo(4.5));
        expect(
          _contrast(t.textSecondary, t.surface),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('a primary button label clears AA against its own fill', () {
        expect(_contrast(t.onAccent, t.accent), greaterThanOrEqualTo(4.5));
      });

      test('every tone foreground is legible on a card', () {
        for (final pair in {
          'accent': t.accent,
          'success': t.success,
          'info': t.info,
          'warning': t.warning,
          'danger': t.danger,
        }.entries) {
          expect(
            _contrast(pair.value, t.surface),
            greaterThanOrEqualTo(3.5),
            reason: '${pair.key} on surface',
          );
        }
      });

      test('the heatmap ramp is monotonic and level 0 holds the grid', () {
        // An empty cell that vanishes into the card destroys the calendar's
        // shape — the old #1B2027 on #1A1F26 measured 1.01:1.
        expect(_contrast(t.heatmap[0], t.surface), greaterThanOrEqualTo(1.25));

        for (var i = 1; i < t.heatmap.length - 1; i++) {
          expect(
            _contrast(t.heatmap[i], t.heatmap[i + 1]),
            greaterThan(1.1),
            reason: 'ramp steps $i and ${i + 1} are too close to separate',
          );
        }
      });

      test('a card is separable from the page behind it', () {
        final fill = _contrast(t.surface, t.ground);
        final edge = _contrast(t.border, t.ground);
        // The border is what does the work; it has to beat the fill difference.
        expect(edge, greaterThan(fill));
        expect(edge, greaterThanOrEqualTo(1.4));
      });

      test('accent and success stay distinguishable', () {
        // The split only means anything if the two read as different colours:
        // "press me" and "your streak is alive" are not the same claim.
        expect(
          (HSLColor.fromColor(t.accent).hue - HSLColor.fromColor(t.success).hue)
              .abs(),
          greaterThan(40),
        );
      });
    });
  }

  test('the brand gradient is the logo, identically in both themes', () {
    // It is chrome, not state. Inverting it per theme would make it a
    // different mark in light mode.
    expect(AppTokens.dark.brandGradient, AppTokens.light.brandGradient);
    expect(AppTokens.dark.brandGradient.length, 3);
  });
}
