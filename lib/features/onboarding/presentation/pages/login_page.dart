import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/entities/device_code.dart';
import '../bloc/auth_bloc.dart';

/// GitHub device flow.
///
/// Phase 1 runs this against a fake so the screen is built against the real
/// timing: a code that expires, a poll that takes a few rounds. Phase 2 swaps
/// the repository for the real one — no change here.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is! AuthAuthorized) return;

        // Record the identity, then let the router's redirect decide where to
        // go — setup is still incomplete, so it lands there.
        final settings = context.read<SettingsBloc>().state;
        if (settings is SettingsLoaded) {
          context.read<SettingsBloc>().add(
            UpdateSettings(settings.settings.copyWith(username: state.login)),
          );
        }
        context.go(Routes.setup);
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) => switch (state) {
                AuthAwaitingUser(:final grant) => _CodeView(grant: grant),
                AuthRequestingCode() => const _Working(
                  message: 'Asking GitHub for a code',
                ),
                AuthAuthorized() => const _Working(message: 'Connected'),
                AuthExpired() => _Retry(
                  title: 'That code expired',
                  message: 'Codes last fifteen minutes. Here is a fresh one.',
                  tone: AppTone.warning,
                ),
                AuthFailed(:final message) => _Retry(
                  title: "Couldn't connect",
                  message: message,
                  tone: AppTone.danger,
                ),
                _ => const _Intro(),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.commit, size: 48, color: t.accent),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Connect GitHub',
          style: text.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'We read your contribution graph to know whether your streak is '
          'safe. Your token stays on this device.',
          style: text.bodyMedium?.copyWith(color: t.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxxl),
        ElevatedButton(
          onPressed: () =>
              context.read<AuthBloc>().add(const StartDeviceFlow()),
          child: const Text('Get a code'),
        ),
      ],
    );
  }
}

class _CodeView extends StatelessWidget {
  const _CodeView({required this.grant});

  final DeviceCodeGrant grant;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enter this code', style: text.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'at ${grant.verificationUri}',
          style: text.bodyMedium?.copyWith(color: t.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          tone: AppTone.accent,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          onTap: () {
            Clipboard.setData(ClipboardData(text: grant.userCode));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Code copied')));
          },
          child: Column(
            children: [
              Text(
                grant.userCode,
                textAlign: TextAlign.center,
                style: text.displayMedium?.copyWith(
                  color: t.accent,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tap to copy',
                style: text.bodySmall?.copyWith(color: t.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _ExpiryCountdown(expiresAt: grant.expiresAt),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              'Waiting for you to authorise',
              style: text.bodySmall?.copyWith(color: t.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        TextButton(
          onPressed: () =>
              context.read<AuthBloc>().add(const CancelDeviceFlow()),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// The code's own fifteen-minute clock, shown so the user is never guessing
/// whether it is still good.
class _ExpiryCountdown extends StatefulWidget {
  const _ExpiryCountdown({required this.expiresAt});

  final DateTime expiresAt;

  @override
  State<_ExpiryCountdown> createState() => _ExpiryCountdownState();
}

class _ExpiryCountdownState extends State<_ExpiryCountdown> {
  late final Stream<int> _tick = Stream.periodic(
    const Duration(seconds: 1),
    (i) => i,
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return StreamBuilder<int>(
      stream: _tick,
      builder: (context, _) {
        final left = widget.expiresAt.difference(DateTime.now());
        final seconds = left.isNegative ? 0 : left.inSeconds;
        final m = (seconds ~/ 60).toString().padLeft(2, '0');
        final s = (seconds % 60).toString().padLeft(2, '0');
        final low = seconds < 120;

        return Text(
          'Expires in $m:$s',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: low ? t.warning : t.textSecondary,
          ),
        );
      },
    );
  }
}

class _Working extends StatelessWidget {
  const _Working({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: AppSpacing.xl),
        Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.tokens.textSecondary),
        ),
      ],
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({
    required this.title,
    required this.message,
    required this.tone,
  });

  final String title;
  final String message;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.refresh,
      title: title,
      message: message,
      tone: tone,
      actionLabel: 'Try again',
      onAction: () => context.read<AuthBloc>().add(const StartDeviceFlow()),
    );
  }
}
