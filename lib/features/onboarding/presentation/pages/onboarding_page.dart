import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_tokens.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingContent> _pages = [
    OnboardingContent(
      title: 'Track Your GitHub Journey',
      description:
          'Monitor your daily commits, contributions, and maintain your coding streak with beautiful visualizations.',
      icon: Icons.show_chart,
      accent: OnboardingAccent.info,
    ),
    OnboardingContent(
      title: 'Never Miss a Day',
      description:
          'Smart notifications remind you to make that one last commit before the day ends.',
      icon: Icons.notifications_active,
      accent: OnboardingAccent.danger,
    ),
    OnboardingContent(
      title: 'Stay Motivated',
      description:
          'Watch your contribution graph grow and celebrate your coding achievements every day.',
      icon: Icons.emoji_events,
      accent: OnboardingAccent.accent,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go(Routes.login);
    }
  }

  void _skip() {
    context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 60),
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? context.tokens.info
                              : context.tokens.textSecondary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  TextButton(onPressed: _skip, child: const Text('Skip')),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _OnboardingPageContent(content: _pages[index]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  child: Text(
                    _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Which semantic token an onboarding page leans on. Stored as a role rather
/// than a Color so the content list stays a plain field — a Color would have to
/// be resolved from a BuildContext, which is not available in an initializer.
enum OnboardingAccent { info, danger, accent }

class OnboardingContent {
  final String title;
  final String description;
  final IconData icon;
  final OnboardingAccent accent;

  OnboardingContent({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
  });
}

class _OnboardingPageContent extends StatelessWidget {
  final OnboardingContent content;

  const _OnboardingPageContent({required this.content});

  Color _accent(BuildContext context) => switch (content.accent) {
    OnboardingAccent.info => context.tokens.info,
    OnboardingAccent.danger => context.tokens.danger,
    OnboardingAccent.accent => context.tokens.accent,
  };

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(content.icon, size: 100, color: accent),
          ),
          const SizedBox(height: 48),
          Text(
            content.title,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            content.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.tokens.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
