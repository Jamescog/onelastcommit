import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/entities.dart';

/// The contribution grid.
///
/// Sequential encoding: one hue, light to dark, five steps — matching
/// github.com so the comparison to the user's own profile is direct. That
/// parity is why the ramp stayed green when the rest of the app moved to the
/// logo's blue: the grid is a mirror of the user's real profile page, not app
/// chrome.
///
/// Because the ramp is a single hue, "today" cannot be marked by fill without
/// disappearing into it. Today carries a ring — and an at-risk today carries a
/// *different kind* of ring, a danger halo with a gap inside it, because two
/// rings that differ only in colour are one red-green judgement at the
/// smallest mark on the screen.
class ContributionHeatmap extends StatefulWidget {
  const ContributionHeatmap({
    required this.days,
    required this.todayDate,
    this.atRiskToday = false,
    super.key,
  });

  final List<ContributionDay> days;

  /// GitHub's label for the current UTC day. Passed in rather than inferred
  /// from `days.last`: under stale or offline data the last row is yesterday,
  /// and a ring drawn there marks the wrong cell.
  final String todayDate;

  final bool atRiskToday;

  @override
  State<ContributionHeatmap> createState() => _ContributionHeatmapState();
}

class _ContributionHeatmapState extends State<ContributionHeatmap> {
  ContributionDay? _selected;

  static const _cell = 13.0;
  static const _gap = 3.0;
  static const _lane = _cell + _gap;

  static final _detail = DateFormat('EEE d MMM');
  static final _month = DateFormat('MMM');

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (widget.days.isEmpty) return const SizedBox.shrink();

    // Pad the leading week so rows line up with weekdays.
    final first = DateTime.parse(widget.days.first.date);
    final lead = first.weekday - 1;
    final cells = <ContributionDay?>[
      ...List.filled(lead, null),
      ...widget.days,
    ];

    final weeks = <List<ContributionDay?>>[];
    for (var i = 0; i < cells.length; i += 7) {
      weeks.add(cells.sublist(i, (i + 7).clamp(0, cells.length)));
    }

    final active = widget.days.where((d) => d.hasContributions).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selection detail sits above the grid so it never shifts the rows.
        // Sized by its own line height rather than a fixed 20px, or it clips
        // as soon as the user scales text up.
        _DetailLine(
          selected: _selected,
          format: _detail,
          style: text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          container: true,
          label:
              'Contribution graph, ${widget.days.length} days, '
              '$active with contributions',
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MonthRow(weeks: weeks, lane: _lane, format: _month),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _WeekdayColumn(cell: _cell, gap: _gap),
                    const SizedBox(width: AppSpacing.xs),
                    for (final week in weeks)
                      Padding(
                        padding: const EdgeInsets.only(right: _gap),
                        child: Column(
                          children: [
                            for (final day in week)
                              Padding(
                                padding: const EdgeInsets.only(bottom: _gap),
                                child: _Cell(
                                  day: day,
                                  isToday:
                                      day != null &&
                                      day.date == widget.todayDate,
                                  atRisk: widget.atRiskToday,
                                  selected: day != null && day == _selected,
                                  format: _detail,
                                  onTap: day == null
                                      ? null
                                      : () => setState(
                                          () => _selected = _selected == day
                                              ? null
                                              : day,
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Legend(cell: _cell, gap: _gap, atRiskToday: widget.atRiskToday),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.selected,
    required this.format,
    required this.style,
  });

  final ContributionDay? selected;
  final DateFormat format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final day = selected;
    if (day == null) {
      return Text(
        'Tap a day for detail',
        style: style?.copyWith(color: t.textSecondary),
      );
    }
    return Text(
      '${day.count} on ${format.format(DateTime.parse(day.date))}',
      style: style?.copyWith(color: t.textPrimary),
    );
  }
}

/// Month ticks across the top, as on github.com — without them the grid is a
/// texture rather than a calendar, and "three weeks ago" is unfindable.
class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.weeks,
    required this.lane,
    required this.format,
  });

  final List<List<ContributionDay?>> weeks;
  final double lane;
  final DateFormat format;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: t.textSecondary);

    // One label per month, placed on the first week that contains its first
    // days. Weeks are fixed-width, so absolute positioning keeps the label
    // over its column no matter how the text scales.
    final labels = <int, String>{};
    var lastMonth = -1;
    for (var i = 0; i < weeks.length; i++) {
      final day = weeks[i].firstWhere((d) => d != null, orElse: () => null);
      if (day == null) continue;
      final date = DateTime.parse(day.date);
      if (date.month != lastMonth && date.day <= 7) {
        labels[i] = format.format(date);
        lastMonth = date.month;
      }
    }

    return SizedBox(
      height: 14,
      width: _WeekdayColumn.width + AppSpacing.xs + weeks.length * lane,
      child: Stack(
        children: [
          for (final entry in labels.entries)
            Positioned(
              left: _WeekdayColumn.width + AppSpacing.xs + entry.key * lane,
              child: Text(entry.value, style: style),
            ),
        ],
      ),
    );
  }
}

/// Mon / Wed / Fri down the side, matching github.com's three-label rhythm.
class _WeekdayColumn extends StatelessWidget {
  const _WeekdayColumn({required this.cell, required this.gap});

  static const width = 24.0;
  static const _labels = {1: 'Mon', 3: 'Wed', 5: 'Fri'};

  final double cell;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: t.textSecondary, fontSize: 9);

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var row = 0; row < 7; row++)
            Padding(
              padding: EdgeInsets.only(bottom: gap),
              child: SizedBox(
                height: cell,
                child: _labels.containsKey(row)
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: Text(_labels[row]!, style: style),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.day,
    required this.isToday,
    required this.atRisk,
    required this.selected,
    required this.format,
    this.onTap,
  });

  final ContributionDay? day;
  final bool isToday;
  final bool atRisk;
  final bool selected;
  final DateFormat format;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const size = _ContributionHeatmapState._cell;

    final d = day;
    if (d == null) return const SizedBox(width: size, height: size);

    final fill = t.heatmap[d.level];
    final atRiskToday = isToday && atRisk;

    // Today reads as a solid ring. An at-risk today reads as a halo — a ring
    // with a visible gap inside it — so the two are separable by shape and
    // not only by the red/white call a 2px annulus makes hard.
    final Widget box;
    if (atRiskToday) {
      box = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: t.danger, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      );
    } else {
      Border? border;
      if (isToday) {
        border = Border.all(color: t.textPrimary, width: 2);
      } else if (selected) {
        border = Border.all(color: t.textPrimary, width: 1.5);
      }
      box = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(3),
          border: border,
        ),
      );
    }

    final date = format.format(DateTime.parse(d.date));
    final label = d.count == 1
        ? '1 contribution on $date'
        : '${d.count} contributions on $date';

    return Semantics(
      button: true,
      selected: selected,
      label: isToday ? '$label, today${atRisk ? ", at risk" : ""}' : label,
      child: GestureDetector(onTap: onTap, child: box),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.cell,
    required this.gap,
    required this.atRiskToday,
  });

  final double cell;
  final double gap;
  final bool atRiskToday;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final style = text.bodySmall?.copyWith(color: t.textSecondary);

    // The key has to draw whatever the grid is drawing. When today is at risk
    // the grid shows a danger halo, so a plain ring here would explain a cell
    // that is not on screen.
    final Widget swatch = atRiskToday
        ? Container(
            width: cell - 2,
            height: cell - 2,
            decoration: BoxDecoration(
              border: Border.all(color: t.danger, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Container(
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: t.heatmap[0],
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          )
        : Container(
            width: cell - 2,
            height: cell - 2,
            decoration: BoxDecoration(
              color: t.heatmap[0],
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: t.textPrimary, width: 2),
            ),
          );

    return Row(
      children: [
        Text('Less', style: style),
        const SizedBox(width: AppSpacing.sm),
        for (final c in t.heatmap)
          Padding(
            padding: EdgeInsets.only(right: gap),
            child: Container(
              width: cell - 2,
              height: cell - 2,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        const SizedBox(width: AppSpacing.xs),
        Text('More', style: style),
        const Spacer(),
        swatch,
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            atRiskToday ? 'Today · at risk' : 'Today',
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
