import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_tokens.dart';
import '../bloc/tracker_bloc.dart';
import 'tabs/repos_tab.dart';
import 'tabs/stats_tab.dart';
import 'tabs/today_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 168,
            pinned: true,
            backgroundColor: t.ground,
            flexibleSpace: const FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(
                left: AppSpacing.lg,
                bottom: AppSpacing.md,
              ),
              background: SafeArea(child: _ProfileHeader()),
            ),
            actions: [
              BlocBuilder<TrackerBloc, TrackerState>(
                buildWhen: (a, b) => _syncing(a) != _syncing(b),
                builder: (context, state) => _syncing(state)
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push(Routes.settings),
              ),
            ],
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarHeader(
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Today'),
                  Tab(text: 'Stats'),
                  Tab(text: 'Repos'),
                ],
              ),
              background: t.ground,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: const [TodayTab(), StatsTab(), ReposTab()],
        ),
      ),
    );
  }

  static bool _syncing(TrackerState s) => s is TrackerLoaded && s.isSyncing;
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return BlocBuilder<TrackerBloc, TrackerState>(
      builder: (context, state) {
        final profile = state is TrackerLoaded ? state.profile : null;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [t.accentSubtle, t.ground],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.huge,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: t.accent,
                child: Text(
                  profile?.initial ?? '·',
                  style: text.titleLarge?.copyWith(color: t.onAccent),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile?.name ?? 'One Last Commit',
                      style: text.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (profile != null)
                      Text(
                        '@${profile.login}',
                        style: text.bodySmall?.copyWith(color: t.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabBarHeader extends SliverPersistentHeaderDelegate {
  _TabBarHeader(this.tabBar, {required this.background});

  final TabBar tabBar;
  final Color background;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      ColoredBox(color: background, child: tabBar);

  @override
  bool shouldRebuild(_TabBarHeader oldDelegate) =>
      oldDelegate.background != background || oldDelegate.tabBar != tabBar;
}
