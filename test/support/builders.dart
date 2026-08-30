import 'package:olc/core/util/utc_date.dart';
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

String label(DateTime d) => utcDateLabel(d);
