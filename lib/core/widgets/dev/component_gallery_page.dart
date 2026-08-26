import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../widgets.dart';

/// Every shared component, in either theme, on one scrollable page.
///
/// Debug-only. Launch with:
///
/// ```
/// flutter run --dart-define=GALLERY=true
/// ```
///
/// The theme selector rebuilds the body under an explicit [Theme] rather than
/// changing the app's mode, so both palettes can be checked without leaving the
/// page or restarting.
class ComponentGalleryPage extends StatefulWidget {
  const ComponentGalleryPage({super.key});

  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  Brightness _brightness = Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final theme = _brightness == Brightness.dark
        ? AppTheme.dark
        : AppTheme.light;

    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: context.tokens.ground,
            appBar: AppBar(
              title: const Text('Components'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                  child: SegmentedButton<Brightness>(
                    segments: const [
                      ButtonSegment(
                        value: Brightness.light,
                        icon: Icon(Icons.light_mode_outlined, size: 16),
                      ),
                      ButtonSegment(
                        value: Brightness.dark,
                        icon: Icon(Icons.dark_mode_outlined, size: 16),
                      ),
                    ],
                    selected: {_brightness},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setState(() => _brightness = s.first),
                  ),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: const [
                _Group(title: 'Cards', child: _CardsDemo()),
                _Group(title: 'Section headers', child: _HeadersDemo()),
                _Group(title: 'Stats', child: _StatsDemo()),
                _Group(title: 'Pills', child: _PillsDemo()),
                _Group(title: 'Heatmap ramp', child: _HeatmapDemo()),
                _Group(title: 'Type scale', child: _TypeDemo()),
                _Group(title: 'Loading', child: _SkeletonDemo()),
                _Group(title: 'Empty state', child: _EmptyDemo()),
                _Group(title: 'Error state', child: _ErrorDemo()),
                SizedBox(height: AppSpacing.massive),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: t.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(color: t.border, height: 1),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _CardsDemo extends StatelessWidget {
  const _CardsDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: AppSpacing.md,
      children: [
        const AppCard(child: Text('A plain card. Surface, border, no shadow.')),
        AppCard(
          tone: AppTone.danger,
          accentEdge: true,
          child: const Text('At risk — 3h left on your 47-day streak.'),
        ),
        AppCard(
          tone: AppTone.accent,
          accentEdge: true,
          child: const Text('Streak saved. 48 days.'),
        ),
        AppCard(
          tone: AppTone.warning,
          child: const Text("Can't check right now — showing cached data."),
        ),
        AppCard(
          onTap: () {},
          child: const Text('A tappable card, with ink feedback.'),
        ),
      ],
    );
  }
}

class _HeadersDemo extends StatelessWidget {
  const _HeadersDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: AppSpacing.xl,
      children: [
        const SectionHeader(title: 'Today'),
        SectionHeader(
          title: "Today's activity",
          actionLabel: 'View all',
          onAction: () {},
        ),
        const SectionHeader(
          eyebrow: 'Since 26 Aug 2026',
          title: 'Your rhythm',
          subtitle: 'Based on 62 days of tracked activity.',
        ),
      ],
    );
  }
}

class _StatsDemo extends StatelessWidget {
  const _StatsDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: AppSpacing.xl,
      children: [
        const AppCard(
          child: StatTile(
            value: '47',
            label: 'Day streak',
            emphasis: StatEmphasis.hero,
            tone: AppTone.accent,
          ),
        ),
        const AppCard(
          child: StatTileRow(
            tiles: [
              StatTile(value: '12', label: 'This week'),
              StatTile(value: '89', label: 'This month'),
              StatTile(value: '3h', label: 'Left today', tone: AppTone.danger),
            ],
          ),
        ),
        const AppCard(
          child: StatTileRow(
            tiles: [
              StatTile(
                value: '18',
                label: 'Saves',
                icon: Icons.shield_outlined,
                tone: AppTone.accent,
                emphasis: StatEmphasis.compact,
              ),
              StatTile(
                value: '11m',
                label: 'Closest call',
                icon: Icons.timer_outlined,
                tone: AppTone.warning,
                emphasis: StatEmphasis.compact,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PillsDemo extends StatelessWidget {
  const _PillsDemo();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        AppPill(label: 'Counted', tone: AppTone.accent, icon: Icons.check),
        AppPill(label: 'At risk', tone: AppTone.danger, icon: Icons.warning),
        AppPill(label: 'Stale', tone: AppTone.warning, icon: Icons.schedule),
        AppPill(label: 'Public', tone: AppTone.info),
        AppPill(label: 'main'),
        AppPill(label: 'Outlined', tone: AppTone.accent, filled: false),
      ],
    );
  }
}

class _HeatmapDemo extends StatelessWidget {
  const _HeatmapDemo();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: AppSpacing.xs,
          children: [
            for (final c in t.heatmap)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            const SizedBox(width: AppSpacing.md),
            // Today and at-risk share the ramp's hue, so they are marked by
            // treatment rather than fill — see PLAN.md commit 10.
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: t.heatmap[2],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: t.textPrimary, width: 2),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: t.heatmap[0],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: t.danger, width: 2),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Levels 0–4, then today (ring) and at risk (danger ring).',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
        ),
      ],
    );
  }
}

class _TypeDemo extends StatelessWidget {
  const _TypeDemo();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        Text('47', style: text.displayLarge),
        Text('Never miss a day', style: text.headlineMedium),
        Text('Today', style: text.titleLarge),
        Text(
          'Body text sits at sixteen pixels with a comfortable line height.',
          style: text.bodyLarge,
        ),
        Text('Secondary body copy, fourteen.', style: text.bodyMedium),
        Text('EYEBROW LABEL', style: text.labelSmall),
      ],
    );
  }
}

class _SkeletonDemo extends StatelessWidget {
  const _SkeletonDemo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.md,
      children: [
        Row(
          spacing: AppSpacing.md,
          children: [
            Skeleton.circle(size: 40),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.sm,
                children: [Skeleton.line(width: 140), Skeleton.line(width: 90)],
              ),
            ),
          ],
        ),
        SkeletonCard(),
      ],
    );
  }
}

class _EmptyDemo extends StatelessWidget {
  const _EmptyDemo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: EmptyStateView(
        icon: Icons.commit_outlined,
        title: 'Nothing counted yet today',
        message:
            'Push to a default branch, open an issue, or review a pull '
            'request to keep the streak alive.',
        actionLabel: 'Refresh',
        onAction: () {},
      ),
    );
  }
}

class _ErrorDemo extends StatelessWidget {
  const _ErrorDemo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: ErrorStateView(
        title: "Couldn't reach GitHub",
        message: 'Showing what we last knew. Your streak may have changed.',
        onRetry: () {},
      ),
    );
  }
}
