import 'package:olc/features/tracker/domain/entities/entities.dart';

/// Builds a run of days ending on [end], with [counts] oldest-first.
List<ContributionDay> daysEnding(DateTime end, List<int> counts) {
  return [
    for (var i = 0; i < counts.length; i++)
      ContributionDay(
        date: label(end.subtract(Duration(days: counts.length - 1 - i))),
        count: counts[i],
        level: counts[i] == 0 ? 0 : 1,
        lastContributionAt: counts[i] == 0
            ? null
            : end
                  .subtract(Duration(days: counts.length - 1 - i))
                  .add(const Duration(hours: 20)),
      ),
  ];
}

String label(DateTime d) {
  final u = d.toUtc();
  return '${u.year.toString().padLeft(4, '0')}-'
      '${u.month.toString().padLeft(2, '0')}-'
      '${u.day.toString().padLeft(2, '0')}';
}
