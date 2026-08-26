import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// A single-series area chart of recent daily contributions.
///
/// One series, so no legend — the section title names it. One axis, always:
/// two measures of different scale would get two charts rather than a second
/// y-scale. Grid and axis stay recessive; the endpoint is emphasised because
/// "where it is now" is the thing being read.
class TrendChart extends StatelessWidget {
  const TrendChart({required this.values, this.height = 96, super.key});

  final List<int> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();
    final t = context.tokens;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _TrendPainter(
          values: values,
          line: t.accent,
          fill: t.accent.withValues(alpha: 0.14),
          grid: t.border,
          endpoint: t.accent,
          endpointRing: t.surface,
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.values,
    required this.line,
    required this.fill,
    required this.grid,
    required this.endpoint,
    required this.endpointRing,
  });

  final List<int> values;
  final Color line;
  final Color fill;
  final Color grid;
  final Color endpoint;
  final Color endpointRing;

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final top = maxV == 0 ? 1.0 : maxV.toDouble();
    final dx = size.width / (values.length - 1);

    double yFor(int v) => size.height - (v / top) * (size.height - 6) - 3;

    // Recessive baseline only — a full grid would compete with the mark.
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );

    final path = Path()..moveTo(0, yFor(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(i * dx, yFor(values[i]));
    }

    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);

    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // A 2px surface ring keeps the endpoint legible where it overlaps the fill.
    final last = Offset(size.width, yFor(values.last));
    canvas.drawCircle(last, 5, Paint()..color = endpointRing);
    canvas.drawCircle(last, 4, Paint()..color = endpoint);
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.values != values || old.line != line;
}
