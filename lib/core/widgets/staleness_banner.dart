import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';
import 'app_tone.dart';

/// Shown wherever the mirror cannot be vouched for.
///
/// It hedges rather than hides. Staying silent risks telling someone their
/// streak is safe when it may not be, and that is the failure this app cannot
/// afford — see PLAN.md section 1.
///
/// It lives in `core/widgets` because PLAN.md section 2.4 asks for the
/// indicator on *every* surface that shows a streak, and for a while it was
/// only on one of the four.
class StalenessBanner extends StatelessWidget {
  const StalenessBanner({required this.isError, this.checkedAt, super.key});

  final bool isError;

  /// When the mirror was last computed. Rendered as an age, because "showing
  /// what we last knew" without saying *when* is not much of a warning.
  final DateTime? checkedAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppCard(
      tone: AppTone.warning,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 16, color: t.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              isError
                  ? 'Cannot reach GitHub${_age()}. This may have changed.'
                  : 'Showing what we last knew${_age()}.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: t.warning),
            ),
          ),
        ],
      ),
    );
  }

  String _age() {
    final at = checkedAt;
    if (at == null) return '';
    final age = DateTime.now().toUtc().difference(at.toUtc());
    if (age.isNegative || age < const Duration(minutes: 2)) {
      return ' — checked just now';
    }
    if (age < const Duration(hours: 1)) {
      return ' — checked ${age.inMinutes}m ago';
    }
    if (age < const Duration(days: 1)) return ' — checked ${age.inHours}h ago';
    return ' — checked ${age.inDays}d ago';
  }
}
