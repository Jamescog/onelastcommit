import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Whether the OS will actually let us remind anyone.
///
/// Reported rather than assumed. A reminder app that shows reminders as "on"
/// while Android has denied the permission is lying about the one thing it
/// exists to do.
class NotificationPermissions {
  const NotificationPermissions({
    required this.notificationsAllowed,
    required this.exactAlarmsAllowed,
  });

  final bool notificationsAllowed;

  /// Android 12+ gates exact alarms, and from 14 it is not granted on install
  /// for most apps. Without it a reminder can drift by tens of minutes, which
  /// near a deadline is the difference between useful and pointless.
  final bool exactAlarmsAllowed;

  bool get canRemindReliably => notificationsAllowed && exactAlarmsAllowed;
}

class NotificationService {
  NotificationService._();

  factory NotificationService() => _instance;
  static final NotificationService _instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// The nag. Loud on purpose — it is the product.
  static const remindersChannel = 'olc_reminders';

  /// Confirmations. Quiet: telling someone their streak is safe should never
  /// interrupt them.
  static const savedChannel = 'olc_saved';

  /// Null on any platform without the Android plugin, and also before [init]
  /// has run — resolving throws in that state rather than returning null, so
  /// the lookup is guarded.
  AndroidFlutterLocalNotificationsPlugin? get _android {
    try {
      return _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    tzdata.initializeTimeZones();

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        linux: LinuxInitializationSettings(defaultActionName: 'Open'),
      ),
    );

    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        remindersChannel,
        'Streak reminders',
        description: 'Warns you when nothing has counted yet today',
        importance: Importance.high,
      ),
    );
    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        savedChannel,
        'Streak saved',
        description: 'Confirms the day is covered',
        importance: Importance.low,
      ),
    );
  }

  /// Sets the zone scheduling is done in.
  ///
  /// Reminder times are local, but the deadline they guard is UTC midnight —
  /// see PLAN.md section 2. Getting the zone wrong shifts every reminder.
  void useTimezone(String ianaName) {
    try {
      tz.setLocalLocation(tz.getLocation(ianaName));
    } catch (_) {
      // An unresolvable name is reported by the settings picker; falling back
      // to UTC is better than throwing during startup.
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  Future<NotificationPermissions> permissions() async {
    final android = _android;
    if (android == null) {
      return const NotificationPermissions(
        notificationsAllowed: true,
        exactAlarmsAllowed: true,
      );
    }
    return NotificationPermissions(
      notificationsAllowed: await android.areNotificationsEnabled() ?? false,
      exactAlarmsAllowed:
          await android.canScheduleExactNotifications() ?? false,
    );
  }

  /// Asks for what is missing. Returns the state afterwards, so the caller can
  /// tell the user what is still blocked instead of assuming success.
  Future<NotificationPermissions> request() async {
    final android = _android;
    if (android != null) {
      try {
        await android.requestNotificationsPermission();
        // On Android 14 this cannot be granted in-app; the platform opens its
        // own settings screen and the answer arrives when the user returns.
        await android.requestExactAlarmsPermission();
      } catch (_) {
        // Fall through and report whatever the current state turns out to be.
      }
    }
    return permissions();
  }

  Future<void> showReminder({
    required String title,
    required String body,
    int id = 0,
  }) => _plugin.show(
    id,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        remindersChannel,
        'Streak reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );

  Future<void> showSaved({required String body}) => _plugin.show(
    1,
    'Streak saved',
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        savedChannel,
        'Streak saved',
        importance: Importance.low,
        priority: Priority.low,
      ),
    ),
  );

  /// Registers a reminder with the OS for future delivery. [repeat] makes it
  /// recur: daily at the same time for [DateTimeComponents.time], weekly for
  /// [DateTimeComponents.dayOfWeekAndTime].
  ///
  /// Exact delivery whenever Android allows it — an inexact alarm can drift
  /// by tens of minutes, which next to a deadline is the difference between a
  /// save and a broken streak. The permission card in Settings is where the
  /// user finds out which one they are getting.
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime at,
    required DateTimeComponents repeat,
    required bool exact,
  }) => _plugin.zonedSchedule(
    id,
    title,
    body,
    at,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        remindersChannel,
        'Streak reminders',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
    ),
    androidScheduleMode: exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: repeat,
  );

  Future<List<PendingNotificationRequest>> pending() =>
      _plugin.pendingNotificationRequests();

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();

  FlutterLocalNotificationsPlugin get plugin => _plugin;
}
