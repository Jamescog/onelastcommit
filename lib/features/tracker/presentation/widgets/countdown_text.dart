import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

/// Live countdown to the UTC deadline.
///
/// Its own widget so the per-second rebuild stays confined to this subtree
/// rather than repainting the whole status card once a second.
///
/// The deadline is UTC midnight, which is not midnight anywhere most people
/// live — a user at UTC+13 loses the day thirteen hours before their own
/// clock rolls over. A countdown is unambiguous everywhere; a wall-clock time
/// is not. See PLAN.md section 2.
class CountdownText extends StatefulWidget {
  const CountdownText({
    required this.deadlineUtc,
    this.safe = false,
    super.key,
  });

  final DateTime deadlineUtc;
  final bool safe;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  late Duration _left = _remaining();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left = _remaining());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration _remaining() {
    final left = widget.deadlineUtc.difference(DateTime.now().toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final hours = _left.inHours;
    final minutes = _left.inMinutes % 60;

    // Under two hours the exact minute matters, so it is spelled out.
    final label = hours >= 2
        ? '${hours}h ${minutes}m left today'
        : '${_left.inMinutes}m left today';

    return Row(
      children: [
        Icon(
          widget.safe ? Icons.schedule : Icons.timer_outlined,
          size: 14,
          color: widget.safe ? t.textSecondary : t.danger,
        ),
        const SizedBox(width: 6),
        Text(
          widget.safe ? 'Day closes in ${_compact()}' : label,
          style: text.bodySmall?.copyWith(
            color: widget.safe ? t.textSecondary : t.danger,
          ),
        ),
      ],
    );
  }

  String _compact() {
    final h = _left.inHours;
    return h >= 1 ? '${h}h' : '${_left.inMinutes}m';
  }
}
