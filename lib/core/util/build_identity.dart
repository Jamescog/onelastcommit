import 'package:flutter/foundation.dart';

/// Identifies this build of the app.
///
/// Pass a fresh value per build:
///
/// ```
/// flutter build apk --dart-define=BUILD_ID=$(uuidgen)
/// ```
///
/// When it changes, the local mirror is dropped and refetched. That matters
/// because the mirror is written by parsing code: a build that parses
/// differently — a new field, a corrected mapping, a schema change — would
/// otherwise keep serving rows produced by the old one, and the bug would look
/// like bad data from GitHub rather than a stale cache.
///
/// Without an explicit value this falls back to the debug/release flavour, so
/// a debug build never reuses a release build's rows.
const String buildId = String.fromEnvironment(
  'BUILD_ID',
  defaultValue: kDebugMode ? 'dev' : 'release',
);
