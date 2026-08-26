import 'package:flutter/material.dart';

import '../../../../core/data/mock_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../settings/presentation/pages/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 220,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.deepSpace,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                title: Text(
                  innerBoxIsScrolled ? 'One Last Commit' : '',
                  style: const TextStyle(fontSize: 16),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.commitGreen.withOpacity(0.2),
                        AppColors.deepSpace,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.commitGreen,
                            child: Text(
                              MockUser.mockUser.username[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            MockUser.mockUser.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${MockUser.mockUser.username}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.slateGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  ),
                ),
              ],
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.electricBlue,
                  unselectedLabelColor: AppColors.slateGray,
                  indicatorColor: AppColors.electricBlue,
                  tabs: const [
                    Tab(text: 'Today'),
                    Tab(text: 'Stats'),
                    Tab(text: 'Repos'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [_TodayTab(), _StatsTab(), _ReposTab()],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppColors.deepSpace, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

class _TodayTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final commits = MockData.todayCommits;
    final hasCommitsToday = commits.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMainStatusCard(context, hasCommitsToday),
          const SizedBox(height: 16),
          _buildQuickStats(context),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Activity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.history, size: 18),
                label: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (commits.isEmpty)
            _buildEmptyState(context)
          else
            ...commits.map((commit) => _buildModernCommitCard(context, commit)),
        ],
      ),
    );
  }

  Widget _buildMainStatusCard(BuildContext context, bool hasCommits) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasCommits
              ? [
                  AppColors.commitGreen.withOpacity(0.3),
                  AppColors.electricBlue.withOpacity(0.2),
                ]
              : [
                  AppColors.alertOrange.withOpacity(0.3),
                  AppColors.alertOrange.withOpacity(0.1),
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasCommits ? AppColors.commitGreen : AppColors.alertOrange,
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              hasCommits ? Icons.check_circle : Icons.hourglass_empty,
              size: 140,
              color: hasCommits
                  ? AppColors.commitGreen.withOpacity(0.1)
                  : AppColors.alertOrange.withOpacity(0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: hasCommits
                        ? AppColors.commitGreen
                        : AppColors.alertOrange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hasCommits ? 'ON TRACK' : 'PENDING',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  hasCommits ? 'Awesome Work!' : 'One Last Commit',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasCommits
                      ? '${MockData.todayCommits.length} commits today. Keep it going!'
                      : 'Don\'t break your streak. Push some code today!',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.slateGray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            context,
            '🔥',
            '${MockData.contributionStats['currentStreak']}',
            'Day Streak',
            AppColors.alertOrange.withOpacity(0.2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            context,
            '📊',
            '${MockData.contributionStats['thisWeek']}',
            'This Week',
            AppColors.electricBlue.withOpacity(0.2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickStatCard(
            context,
            '⚡',
            '${MockData.contributionStats['thisMonth']}',
            'This Month',
            AppColors.commitGreen.withOpacity(0.2),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard(
    BuildContext context,
    String emoji,
    String value,
    String label,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModernCommitCard(BuildContext context, MockCommit commit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardBackground,
            AppColors.cardBackground.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.commitGreen,
                AppColors.commitGreen.withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.commit, color: Colors.white, size: 28),
        ),
        title: Text(
          commit.message,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.electricBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                commit.repo,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.electricBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppColors.slateGray,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTimeAgo(commit.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.commitGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '+${commit.additions}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.commitGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.alertOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '-${commit.deletions}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.alertOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.code_off,
              size: 64,
              color: AppColors.slateGray.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No commits yet today',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Time to start coding!',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class _StatsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildContributionGrid(context),
        const SizedBox(height: 24),
        _buildStatsCards(context),
      ],
    );
  }

  Widget _buildContributionGrid(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contribution Activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _ContributionGraph(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(BuildContext context) {
    final stats = MockData.contributionStats;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'Total',
                '${stats['totalContributions']}',
                Icons.code,
                AppColors.electricBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                'This Month',
                '${stats['thisMonth']}',
                Icons.calendar_month,
                AppColors.commitGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'Current Streak',
                '${stats['currentStreak']} days',
                Icons.local_fire_department,
                AppColors.alertOrange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                'Best Streak',
                '${stats['longestStreak']} days',
                Icons.emoji_events,
                AppColors.commitGreen,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ContributionGraph extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final contributions = MockData.contributionMap;
    final sortedDates = contributions.keys.toList()..sort();
    final recentDates = sortedDates.reversed
        .take(91)
        .toList()
        .reversed
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = 13;
        final rows = 7;
        final cellSize = (constraints.maxWidth - (columns - 1) * 4) / columns;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: columns * cellSize + (columns - 1) * 4,
            height: rows * cellSize + (rows - 1) * 4,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              scrollDirection: Axis.horizontal,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: rows,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1,
              ),
              itemCount: recentDates.length,
              itemBuilder: (context, index) {
                final date = recentDates[index];
                final count = contributions[date] ?? 0;

                return Container(
                  decoration: BoxDecoration(
                    color: _getContributionColor(count),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Color _getContributionColor(int count) {
    if (count == 0) return AppColors.borderColor;
    if (count <= 2) return AppColors.commitGreen.withOpacity(0.3);
    if (count <= 4) return AppColors.commitGreen.withOpacity(0.6);
    return AppColors.commitGreen;
  }
}

class _ReposTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: MockData.repositories.length,
      itemBuilder: (context, index) {
        final repo = MockData.repositories[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.electricBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder, color: AppColors.electricBlue),
            ),
            title: Text(
              repo['name'] as String,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  repo['description'] as String,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppColors.electricBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      repo['language'] as String,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.star_border,
                      size: 14,
                      color: AppColors.slateGray,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${repo['stars']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.fork_right,
                      size: 14,
                      color: AppColors.slateGray,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${repo['forks']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
