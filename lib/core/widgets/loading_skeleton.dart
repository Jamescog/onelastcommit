import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_tokens.dart';

/// A shimmering placeholder block.
///
/// Skeletons are used rather than a centred spinner because the app's screens
/// have a known shape before their data arrives — showing that shape avoids the
/// layout jump a spinner causes when it is replaced.
class Skeleton extends StatefulWidget {
  const Skeleton({
    required this.width,
    required this.height,
    this.radius = AppRadius.sm,
    super.key,
  });

  /// A full-width line of text, sized from the body scale.
  const Skeleton.line({double width = double.infinity, Key? key})
    : this(width: width, height: 12, key: key);

  const Skeleton.circle({required double size, Key? key})
    : this(width: size, height: size, radius: AppRadius.pill, key: key);

  final double width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the platform's reduce-motion setting: a shimmer that never stops
    // is exactly the kind of thing it exists to suppress.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = t.surfaceSubtle;
    final highlight = t.border;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: _controller.isAnimating
                  ? LinearGradient(
                      begin: Alignment(-1 - 2 * _controller.value, 0),
                      end: Alignment(1 - 2 * _controller.value, 0),
                      colors: [base, highlight, base],
                      stops: const [0.35, 0.5, 0.65],
                    )
                  : null,
              color: _controller.isAnimating ? null : base,
            ),
          );
        },
      ),
    );
  }
}

/// A card-shaped skeleton matching the proportions of a populated [AppCard].
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({this.lines = 3, super.key});

  final int lines;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(width: 120, height: 16),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < lines; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            Skeleton.line(width: i.isEven ? double.infinity : 200),
          ],
        ],
      ),
    );
  }
}
