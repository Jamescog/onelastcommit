import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';

/// Three screens, then the sign-in.
///
/// Chrome, start to finish — so this is one of the few places allowed to draw
/// the logo's gradient. It carries no state meaning here, which is exactly why
/// it is safe: the previous version painted an 80px icon and every control in
/// `danger`, against the rule written on the token itself, and teaching
/// someone to read the alarm colour as decoration is how you make them ignore
/// it on the day it matters.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _Slide(
      title: 'Your streak runs on GitHub time',
      body:
          'The contribution day closes at midnight UTC, which is not midnight '
          'where you are. One Last Commit counts the day GitHub counts.',
      icon: Icons.public,
    ),
    _Slide(
      title: 'A nudge while there is still room',
      body:
          'Reminders are scheduled in advance and withdrawn once the day is '
          'safe, so a missed background check means a spare nudge — never a '
          'silent night.',
      icon: Icons.notifications_active_outlined,
    ),
    _Slide(
      title: 'Including the work that never counted',
      body:
          'Pushes to a branch your repository does not count earn no square. '
          'This is the app that tells you where they went.',
      icon: Icons.query_stats_outlined,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  _Dots(count: _pages.length, active: _currentPage),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go(Routes.login),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemCount: _pages.length,
                itemBuilder: (context, index) =>
                    _SlideView(slide: _pages[index], index: index),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(last ? 'Get started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: 'Page ${active + 1} of $count',
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: AppSpacing.xs),
              width: i == active ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == active ? t.accent : t.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
        ],
      ),
    );
  }
}

class _Slide {
  const _Slide({required this.title, required this.body, required this.icon});

  final String title;
  final String body;
  final IconData icon;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.index});

  final _Slide slide;
  final int index;

  /// The gradient rotates a third of a turn per slide, so the three read as
  /// one mark seen from three angles rather than three different colours.
  static const _alignments = [
    (Alignment.topLeft, Alignment.bottomRight),
    (Alignment.topRight, Alignment.bottomLeft),
    (Alignment.topCenter, Alignment.bottomCenter),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final (begin, end) = _alignments[index % _alignments.length];

    // Scrollable, because the previous version was a fixed Column inside a
    // PageView and overflowed on a small phone at 1.5x text.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        children: [
          Container(
            width: 168,
            height: 168,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: begin,
                end: end,
                colors: [
                  for (final c in t.brandGradient) c.withValues(alpha: 0.24),
                ],
              ),
            ),
            child: Icon(slide.icon, size: 68, color: t.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            slide.title,
            style: text.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            slide.body,
            style: text.bodyLarge?.copyWith(color: t.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
