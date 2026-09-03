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
    final top = repos.isEmpty
        ? 1
        : repos.map((r) => r.contributionCount).reduce((a, b) => a > b ? a : b);

    // The header and banner are items in the same list as the cards, so a
    // hundred repositories scroll as one surface and only the visible cards
    // are built.
    final lead = <Widget>[
      if (streak.isUncertain) ...[
        StalenessBanner(
          isError: streak.freshness == DataFreshness.error,
          checkedAt: streak.checkedAt,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      const SectionHeader(
        title: 'Repositories you committed to',
        subtitle: 'Last two years, by contribution count',
      ),
      const SizedBox(height: AppSpacing.md),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: lead.length + repos.length + 1,
      itemBuilder: (context, index) {
        if (index < lead.length) return lead[index];
        final i = index - lead.length;
        if (i == repos.length) {
          return const SizedBox(height: AppSpacing.massive);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _RepoCard(repo: repos[i], max: top),
        );
      },
    );
  }
}

class _RepoCard extends StatelessWidget {
  const _RepoCard({required this.repo, required this.max});

  final RepoContribution repo;
  final int max;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final share = max == 0 ? 0.0 : repo.contributionCount / max;

    return AppCard(
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
            color: t.success,
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
                const AppPill(label: 'Fork', icon: Icons.call_split),
            ],
          ),
        ],
      ),
    );
  }
}
