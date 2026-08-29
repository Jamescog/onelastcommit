import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/util/notification_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../injection_container.dart';
import '../bloc/settings_bloc.dart';

/// Shows what the OS is actually allowing.
///
/// A reminder app whose switch says "on" while Android has denied the
/// permission is lying about the only thing it does. This asks the platform
/// rather than trusting the app's own setting.
class PermissionNotice extends StatefulWidget {
  const PermissionNotice({super.key});

  @override
  State<PermissionNotice> createState() => _PermissionNoticeState();
}

class _PermissionNoticeState extends State<PermissionNotice>
    with WidgetsBindingObserver {
  NotificationPermissions? _state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Exact-alarm permission is granted on a system settings screen, so the
    // answer only arrives when the user comes back.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final next = await sl<NotificationService>().permissions();
    _apply(next);
  }

  Future<void> _request() async {
    final next = await sl<NotificationService>().request();
    _apply(next);
  }

  void _apply(NotificationPermissions next) {
    if (!mounted) return;
    // Exact-vs-inexact delivery is baked into each schedule when it is
    // written, so a permission that changed after the fact only takes effect
    // once the reminders are registered again.
    if (_state != null &&
        _state!.exactAlarmsAllowed != next.exactAlarmsAllowed) {
      context.read<SettingsBloc>().add(ReapplyReminders());
    }
    setState(() => _state = next);
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    if (s == null || s.canRemindReliably) return const SizedBox.shrink();

    final t = context.tokens;
    final blocked = !s.notificationsAllowed;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        tone: blocked ? AppTone.danger : AppTone.warning,
        accentEdge: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              blocked ? 'Reminders are blocked' : 'Reminders may arrive late',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: blocked ? t.danger : t.warning,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              blocked
                  ? 'Android is not allowing notifications, so nothing will '
                        'warn you about your streak.'
                  : 'Without permission for exact alarms, Android can delay a '
                        'reminder by tens of minutes — long enough to miss the '
                        'deadline it is meant to protect.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: _request,
              child: Text(
                blocked ? 'Allow notifications' : 'Allow exact alarms',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
