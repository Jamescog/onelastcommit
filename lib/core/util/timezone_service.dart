import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

/// Resolving the device's IANA zone.
///
/// `DateTime.now().timeZoneName` is not usable for this: it returns
/// abbreviations like "EAT", which are ambiguous and are not identifiers any
/// zone database can resolve. The platform knows the real one; this asks it.
class TimezoneService {
  const TimezoneService();

  /// The device's zone, or null when the platform will not say or returns
  /// something the database does not recognise.
  Future<String?> detect() async {
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      return isValid(name.identifier) ? name.identifier : null;
    } catch (_) {
      return null;
    }
  }

  static bool isValid(String name) {
    try {
      tz.getLocation(name);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Every zone the database knows, sorted. 431 of them — the previous setup
  /// screen offered fifteen hardcoded cities, none of them African.
  static List<String> all() =>
      tz.timeZoneDatabase.locations.keys.toList()..sort();

  /// Zones sharing the given zone's current offset.
  ///
  /// Used to suggest neighbours when the exact zone cannot be detected: the
  /// offset is nearly always right even when the city is not.
  static List<String> sharingOffsetWith(String name) {
    if (!isValid(name)) return const [];
    final now = DateTime.now();
    final target = tz.TZDateTime.from(now, tz.getLocation(name)).timeZoneOffset;
    return [
      for (final zone in all())
        if (tz.TZDateTime.from(now, tz.getLocation(zone)).timeZoneOffset ==
            target)
          zone,
    ];
  }

  /// "+03:00" for display beside a zone name.
  static String offsetLabel(String name) {
    if (!isValid(name)) return '';
    final offset = tz.TZDateTime.from(
      DateTime.now(),
      tz.getLocation(name),
    ).timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final h = abs.inHours.toString().padLeft(2, '0');
    final m = (abs.inMinutes % 60).toString().padLeft(2, '0');
    return '$sign$h:$m';
  }
}
