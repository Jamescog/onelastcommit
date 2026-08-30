import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olc/core/theme/app_theme.dart';
import 'package:olc/core/widgets/widgets.dart';

/// The bar drew its track and no fill.
///
/// A Stack gives its unpositioned children loose constraints, so the fill's
/// ColoredBox took `constraints.smallest` — zero height — and painted
/// nothing. Nothing caught it: the widget built, laid out and passed analysis,
/// and the track it left behind was the same colour as the card it sat on, so
/// on the repos screen the whole bar simply was not there.
///
/// These assert the geometry rather than the pixels, because the geometry is
/// what was wrong.
void main() {
  Future<void> pumpBar(WidgetTester tester, double value) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: ProportionBar(value: value, label: 'share'),
            ),
          ),
        ),
      ),
    );
  }

  // Scaffold and Material bring Stacks of their own, so every finder here is
  // scoped to the bar.
  RenderBox trackBox(WidgetTester tester) => tester.renderObject<RenderBox>(
    find.descendant(
      of: find.byType(ProportionBar),
      matching: find.byType(Stack),
    ),
  );

  Size fillSize(WidgetTester tester) => tester
      .renderObject<RenderBox>(
        find.descendant(
          of: find.byType(FractionallySizedBox),
          matching: find.byType(ColoredBox),
        ),
      )
      .size;

  testWidgets('the fill is drawn at the bar height, not zero', (tester) async {
    await pumpBar(tester, 0.5);
    expect(fillSize(tester).height, 4);
    expect(fillSize(tester).width, 100);
  });

  testWidgets('the track spans the full width behind it', (tester) async {
    await pumpBar(tester, 0.25);
    expect(trackBox(tester).size.width, 200);
    expect(fillSize(tester).width, 50);
  });

  testWidgets('the fill starts at the leading edge', (tester) async {
    // FractionallySizedBox centres by default, which would leave a 20% bar
    // floating in the middle of its own track.
    await pumpBar(tester, 0.2);
    final fill = tester.renderObject<RenderBox>(
      find.descendant(
        of: find.byType(FractionallySizedBox),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(
      fill.localToGlobal(Offset.zero).dx,
      trackBox(tester).localToGlobal(Offset.zero).dx,
    );
  });

  testWidgets('a share past the end and a NaN both stay in range', (
    tester,
  ) async {
    await pumpBar(tester, 1.8);
    expect(fillSize(tester).width, 200);
    await pumpBar(tester, double.nan);
    expect(fillSize(tester).width, 0);
  });
}
