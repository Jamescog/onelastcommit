import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../bloc/tracker_bloc.dart';

class ReposTab extends StatelessWidget {
  const ReposTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrackerBloc, TrackerState>(
      builder: (context, state) {
        if (state is TrackerLoaded) {
          if (state.repos.isEmpty) {
            return const EmptyStateView(
              icon: Icons.folder_outlined,
              title: 'No repositories yet',
              message:
                  'Repositories appear here once you have contributed '
                  'to one.',
            );
          }
          return _Loaded(state: state);
        }
        if (state is TrackerFailure) {
          return ErrorStateView(
            title: 'Repositories unavailable',
            message: state.message,
            onRetry: () => context.read<TrackerBloc>().add(const SyncTracker()),
          );
        }
        if (state is TrackerEmpty) {
          return const EmptyStateView(
            icon: Icons.folder_outlined,
            title: 'No repositories yet',
            message: 'Fetch your history from the Today tab first.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: const [
            SkeletonCard(lines: 1),
            SizedBox(height: AppSpacing.sm),
            SkeletonCard(lines: 1),
            SizedBox(height: AppSpacing.sm),
            SkeletonCard(lines: 1),
          ],
        );
      },
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.state});

  final TrackerLoaded state;

  @override
  Widget build(BuildContext context) {
    final repos = state.repos;
    final streak = state.streak;
    final problem = repos.where((r) => r.hasUncountedWork).toList();
    final top = repos.isEmpty
        ? 1
        : repos.map((r) => r.contributionCount).reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (streak.isUncertain) ...[
          StalenessBanner(
            isError: streak.freshness == DataFreshness.error,
            checkedAt: streak.checkedAt,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        // Repos silently eating contributions come first — this is the answer
        // to "why did my streak break", so it should not be scrolled to.
        if (problem.isNotEmpty) ...[
          const SectionHeader(
            title: 'Work that never counted',
            subtitle:
                'Recent public pushes that earned no square. GitHub '
                'does not expose enough to make this complete — private '
                'work never appears here.',
          ),
          const SizedBox(height: AppSpacing.md),
          ...problem.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _RepoCard(repo: r, max: top, highlight: true),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
        const SectionHeader(title: 'All repositories'),
        const SizedBox(height: AppSpacing.md),
        ...repos.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _RepoCard(repo: r, max: top),
          ),
        ),
        const SizedBox(height: AppSpacing.massive),
      ],
    );
  }
}

class _RepoCard extends StatelessWidget {
  const _RepoCard({
    required this.repo,
    required this.max,
    this.highlight = false,
  });

  final RepoContribution repo;
  final int max;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final share = max == 0 ? 0.0 : repo.contributionCount / max;

    return AppCard(
      tone: highlight ? AppTone.warning : null,
      accentEdge: highlight,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  repo.name,
                  style: text.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${repo.contributionCount}',
                style: text.titleSmall?.copyWith(color: t.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ProportionBar(
            value: share,
            label:
                '${repo.contributionCount} contributions, share of the top '
                'repository',
            color: highlight ? t.warning : t.success,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (repo.primaryLanguage != null)
                AppPill(label: repo.primaryLanguage!),
              if (repo.isPrivate)
                const AppPill(
                  label: 'Private',
                  tone: AppTone.info,
                  icon: Icons.lock_outline,
                ),
              if (repo.isFork)
                const AppPill(
                  label: 'Fork',
                  tone: AppTone.warning,
                  icon: Icons.call_split,
                ),
              if (repo.hasUncountedWork)
                AppPill(
                  label: "${repo.uncountedPushes} didn't count",
                  tone: AppTone.warning,
                  icon: Icons.block,
                ),
            ],
          ),
          if (repo.isFork) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Commits in a fork never appear on your contribution graph.',
              style: text.bodySmall?.copyWith(color: t.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
