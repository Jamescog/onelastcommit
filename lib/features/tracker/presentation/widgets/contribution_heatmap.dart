import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/entities.dart';

/// The contribution grid.
///
/// Sequential encoding: one hue, light to dark, five steps — matching
/// github.com so the comparison to the user's own profile is direct.
///
/// Because the ramp shares the accent hue, "today" cannot be marked by fill
/// without disappearing into the grid. It carries a ring instead, and an
/// at-risk today carries a danger ring. Treatment, not colour.
class ContributionHeatmap extends StatefulWidget {
  const ContributionHeatmap({
    required this.days,
    this.atRiskToday = false,
    super.key,
  });

  final List<ContributionDay> days;
  final bool atRiskToday;

  @override
  State<ContributionHeatmap> createState() => _ContributionHeatmapState();
}

class _ContributionHeatmapState extends State<ContributionHeatmap> {
  ContributionDay? _selected;

  static const _cell = 13.0;
  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selection detail sits above the grid so it never shifts the rows.
        SizedBox(
          height: 20,
          child: _selected == null
              ? Text(
                  'Tap a day for detail',
                  style: text.bodySmall?.copyWith(color: t.textSecondary),
                )
              : Text(
                  '${_selected!.count} on ${_selected!.date}'
                  '${_selected!.uncountedPushes > 0 ? " · ${_selected!.uncountedPushes} didn't count" : ""}',
                  style: text.bodySmall?.copyWith(color: t.textPrimary),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                            isToday: day != null && day == widget.days.last,
                            atRisk: widget.atRiskToday,
                            selected: day != null && day == _selected,
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
        ),
        const SizedBox(height: AppSpacing.md),
        _Legend(cell: _cell, gap: _gap),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.day,
    required this.isToday,
    required this.atRisk,
    required this.selected,
    this.onTap,
  });

  final ContributionDay? day;
  final bool isToday;
  final bool atRisk;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (day == null) {
      return const SizedBox(
        width: _ContributionHeatmapState._cell,
        height: _ContributionHeatmapState._cell,
      );
    }

    Border? border;
    if (isToday) {
      border = Border.all(color: atRisk ? t.danger : t.textPrimary, width: 2);
    } else if (selected) {
      border = Border.all(color: t.textPrimary, width: 1.5);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _ContributionHeatmapState._cell,
        height: _ContributionHeatmapState._cell,
        decoration: BoxDecoration(
          color: t.heatmap[day!.level],
          borderRadius: BorderRadius.circular(3),
          border: border,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.cell, required this.gap});

  final double cell;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final style = text.bodySmall?.copyWith(color: t.textSecondary);

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
        Container(
          width: cell - 2,
          height: cell - 2,
          decoration: BoxDecoration(
            color: t.heatmap[0],
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: t.textPrimary, width: 2),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text('Today', style: style),
      ],
    );
  }
}
