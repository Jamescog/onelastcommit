import 'package:flutter/foundation.dart';

/// The situations the UI has to handle correctly.
///
/// Every screen state in the app is reachable by selecting one of these, so a
/// state can be checked by hand without a backend, a GitHub account, or waiting
/// for a real streak to break.
enum Scenario {
  /// Mid-length streak, already safe today. The ordinary case.
  healthy('Healthy', 'Streak alive, already contributed today'),

  /// Mid-length streak, nothing yet today, deadline approaching. The state the
  /// whole app exists for.
  atRisk('At risk', 'Streak alive, nothing counted yet today'),

  /// The streak ended yesterday. The moment that is either the app's most
  /// valuable feature or the reason someone uninstalls it.
  brokenYesterday('Broken', 'Streak ended yesterday after 23 days'),

  /// Installed moments ago, almost no history. Everything must degrade
  /// gracefully rather than render empty charts.
  brandNewUser('New user', 'Installed today, no history yet'),

  /// A streak long enough to cross the one-year query boundary, which is where
  /// naive streak maths starts truncating.
  longStreak('Long streak', '312 days, crosses the year boundary'),

  /// Cache is readable but the last refresh failed. Data shows with a
  /// staleness marker; the app must hedge rather than claim certainty.
  offline('Offline', 'Cached data, last refresh failed'),

  /// Nothing readable at all.
  error('Error', 'The read itself failed');

  const Scenario(this.label, this.description);

  final String label;
  final String description;
}

/// The scenario the fake data source is currently serving.
///
/// A [ValueNotifier] so the dev switcher can change it and have dependent
/// widgets rebuild without restarting. Debug-only: in a release build the fake
/// is not registered at all.
final ValueNotifier<Scenario> activeScenario = ValueNotifier(Scenario.atRisk);
