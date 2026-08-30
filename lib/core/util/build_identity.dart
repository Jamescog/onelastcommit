import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Identifies this build of the app.
///
/// When it changes, the local mirror is dropped and refetched. That matters
/// because the mirror is written by parsing code: a build that parses
/// differently — a new field, a corrected mapping, a schema change — would
/// otherwise keep serving rows produced by the old one, and the bug would look
/// like bad data from GitHub rather than a stale cache.
///
/// The identity is read from the installed package rather than a build flag,
/// because a flag only resyncs when whoever runs the build remembers to pass
/// one — and the build where you forget is exactly the build whose parsing you
/// changed. Android's `lastUpdateTime` moves every time an APK is installed
/// over the previous one, so every side-loaded build resyncs by itself.
///
/// `--dart-define=BUILD_ID=...` still wins, for forcing a resync without
/// reinstalling.
class BuildIdentity {
  const BuildIdentity._();

  static const _explicit = String.fromEnvironment('BUILD_ID');

  static String _value = _explicit.isEmpty
      ? (kDebugMode ? 'dev' : 'release')
      : _explicit;

  /// The resolved identity. Before [resolve] completes this is the flag — or,
  /// failing that, the build flavour: stable rather than wrong, so nothing
  /// resyncs on a guess.
  static String get value => _value;

  /// Reads the package identity. Call once, before the first mirror read.
  static Future<void> resolve() async {
    if (_explicit.isNotEmpty) return;
    try {
      final info = await PackageInfo.fromPlatform();
      final stamp =
          (info.updateTime ?? info.installTime)?.millisecondsSinceEpoch;
      _value =
          '${info.version}+${info.buildNumber}${stamp == null ? '' : '@$stamp'}';
    } catch (_) {
      // Keep the fallback. Refetching everything on every launch would be a
      // worse answer than trusting a mirror we cannot date.
    }
  }
}
