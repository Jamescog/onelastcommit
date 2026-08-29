import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Brings the app back in front of the device-flow browser page.
///
/// The device flow has no callback URL, so GitHub cannot redirect anyone
/// anywhere — the return trip has to be forced from our side once the poll
/// resolves.
class ForegroundService {
  static const _channel = MethodChannel('olc/foreground');

  /// Dismisses the in-app browser and puts the app back on top.
  ///
  /// [closeInAppWebView] covers iOS, where the SFSafariViewController can be
  /// dismissed directly. On Android it is a no-op for Custom Tabs, so the
  /// platform side instead relaunches the activity with CLEAR_TOP, which pops
  /// the tab off the task. Safe to call when no browser is open.
  static Future<void> reclaimForeground() async {
    try {
      await closeInAppWebView();
      if (!kIsWeb && Platform.isAndroid) {
        await _channel.invokeMethod<void>('bringToFront');
      }
    } on PlatformException {
      // Losing the shortcut back is not worth surfacing; the user can still
      // switch apps by hand, which is where they were without this.
    }
  }
}
