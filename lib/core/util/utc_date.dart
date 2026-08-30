/// GitHub's label for the UTC day a moment falls in.
///
/// This is the primitive the whole app's correctness turns on. Contributions
/// are stamped in UTC and the calendar labels days in UTC, so every comparison
/// between "the day the user is having" and "the day GitHub is counting" comes
/// back to this one function — see PLAN.md section 2.
///
/// It lives here because it used to live in six places, one of which quietly
/// used local components instead, and a disagreement between any two of them
/// is a day the app gets wrong by up to fourteen hours.
String utcDateLabel(DateTime at) {
  final u = at.toUtc();
  return '${u.year.toString().padLeft(4, '0')}-'
      '${u.month.toString().padLeft(2, '0')}-'
      '${u.day.toString().padLeft(2, '0')}';
}
