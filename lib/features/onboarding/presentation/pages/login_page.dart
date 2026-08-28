import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/entities/device_code.dart';
import '../bloc/auth_bloc.dart';

/// GitHub device flow.
///
/// The device flow has no callback URL, so nothing can redirect the user back
/// here. GitHub is opened in a Custom Tab instead of a separate browser app,
/// which keeps this app in the same task and lets [closeInAppWebView] dismiss
/// it the moment the poll succeeds — otherwise someone finishes on github.com,
/// sees a "you're all set" page, and has no idea they are meant to switch back.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (a, b) => a.runtimeType != b.runtimeType,
      listener: (context, state) {
        // Whatever the outcome, the browser has nothing left to show. Get it
        // out of the way so the result is not hidden behind it.
        if (state is AuthAuthorized ||
            state is AuthFailed ||
            state is AuthExpired) {
          closeInAppWebView();
        }
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
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) => switch (state) {
              AuthAwaitingUser(:final grant, :final hint) => _CodeView(
                grant: grant,
                hint: hint,
              ),
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
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
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
      ),
    );
  }
}

/// The code, and the two things the user has to do with it.
///
/// Laid out as numbered steps from the top rather than a centred block: the
/// screen is a set of instructions, and instructions that float in the middle
/// of a tall empty page read as a status message instead.
class _CodeView extends StatefulWidget {
  const _CodeView({required this.grant, this.hint});

  final DeviceCodeGrant grant;
  final String? hint;

  @override
  State<_CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends State<_CodeView> {
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _copy();
  }

  void _copy() {
    // On the clipboard the moment it appears, so the browser trip is a paste
    // rather than memorising eight characters and typing them.
    Clipboard.setData(ClipboardData(text: widget.grant.userCode));
  }

  Future<void> _openGitHub() async {
    setState(() => _opened = true);
    await launchUrl(
      Uri.parse(widget.grant.verificationUri),
      // In-app rather than a separate browser app: this is what lets the page
      // be closed for the user once GitHub says yes.
      mode: LaunchMode.inAppBrowserView,
    );
  }

  @override
  Widget build(BuildContext context) {
    final grant = widget.grant;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            children: [
              Text('Two steps and you are in', style: text.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'The code below is already on your clipboard.',
                style: text.bodyMedium?.copyWith(color: t.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xxl),

              _Step(
                number: 1,
                title: 'Copy this code',
                child: AppCard(
                  tone: AppTone.accent,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                  ),
                  onTap: () {
                    _copy();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied')),
                    );
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          grant.userCode,
                          style: text.headlineLarge?.copyWith(
                            color: t.accent,
                            letterSpacing: 3,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                      Icon(Icons.copy_rounded, size: 20, color: t.accent),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              _Step(
                number: 2,
                title: 'Paste it on github.com',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _openGitHub,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(
                        _opened ? 'Open GitHub again' : 'Open GitHub',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'This page closes itself once GitHub approves — you do '
                      'not need to come back by hand.',
                      style: text.bodySmall?.copyWith(color: t.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              _ExpiryCountdown(expiresAt: grant.expiresAt),
            ],
          ),
        ),

        // Pinned to the bottom: the status of the wait is not a step, and it
        // should not move as the steps above change height.
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: t.border)),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.sm,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Flexible(
                    child: Text(
                      widget.hint ??
                          (_opened
                              ? 'Waiting for GitHub to confirm'
                              : 'Waiting — this page updates by itself'),
                      style: text.bodySmall?.copyWith(
                        color: widget.hint == null
                            ? t.textSecondary
                            : t.warning,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () =>
                    context.read<AuthBloc>().add(const CancelDeviceFlow()),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A numbered instruction. The number is the thing that makes the screen read
/// as a sequence rather than a pile of controls.
class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.child,
  });

  final int number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.surfaceSubtle,
                shape: BoxShape.circle,
                border: Border.all(color: t.border),
              ),
              child: Text(
                '$number',
                style: text.labelSmall?.copyWith(color: t.textSecondary),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(title, style: text.titleSmall),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        child,
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
          'This code expires in $m:$s',
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.xl),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: EmptyStateView(
        icon: Icons.refresh,
        title: title,
        message: message,
        tone: tone,
        actionLabel: 'Try again',
        onAction: () => context.read<AuthBloc>().add(const StartDeviceFlow()),
      ),
    );
  }
}
