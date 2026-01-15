class MockUser {
  final String username;
  final String name;
  final String avatarUrl;
  final int followers;
  final int following;
  final int publicRepos;
  final String bio;
  final String location;

  const MockUser({
    required this.username,
    required this.name,
    required this.avatarUrl,
    required this.followers,
    required this.following,
    required this.publicRepos,
    required this.bio,
    required this.location,
  });

  static const mockUser = MockUser(
    username: 'techdev_james',
    name: 'James Developer',
    avatarUrl: 'https://api.dicebear.com/7.x/avataaars/png?seed=james',
    followers: 234,
    following: 189,
    publicRepos: 47,
    bio: 'Flutter & Dart enthusiast | Building the future one commit at a time',
    location: 'San Francisco, CA',
  );
}

class MockCommit {
  final String message;
  final String repo;
  final DateTime timestamp;
  final int additions;
  final int deletions;
  final String sha;

  const MockCommit({
    required this.message,
    required this.repo,
    required this.timestamp,
    required this.additions,
    required this.deletions,
    required this.sha,
  });
}

class MockData {
  static final List<MockCommit> todayCommits = [
    MockCommit(
      message: 'feat: implement GitHub auth flow',
      repo: 'olc-app',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      additions: 145,
      deletions: 23,
      sha: 'a3f4d2c',
    ),
    MockCommit(
      message: 'fix: resolve notification timing issue',
      repo: 'olc-app',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      additions: 34,
      deletions: 12,
      sha: 'b7e9f1a',
    ),
    MockCommit(
      message: 'docs: update README with new features',
      repo: 'portfolio',
      timestamp: DateTime.now().subtract(const Duration(hours: 8)),
      additions: 67,
      deletions: 5,
      sha: 'c2d8e4b',
    ),
  ];

  static final List<MockCommit> yesterdayCommits = [
    MockCommit(
      message: 'refactor: clean up database queries',
      repo: 'backend-api',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      additions: 89,
      deletions: 112,
      sha: 'd5f6a9c',
    ),
    MockCommit(
      message: 'feat: add user profile customization',
      repo: 'olc-app',
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 7)),
      additions: 234,
      deletions: 45,
      sha: 'e8c7b2d',
    ),
  ];

  static final Map<DateTime, int> contributionMap = _generateContributions();

  static Map<DateTime, int> _generateContributions() {
    final map = <DateTime, int>{};
    final now = DateTime.now();
    
    for (int i = 0; i < 365; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      
      if (i < 7) {
        map[date] = 3 + (i % 2);
      } else if (i < 30) {
        map[date] = [0, 1, 2, 3, 5, 7, 4][(i ~/ 3) % 7];
      } else if (i < 90) {
        map[date] = [0, 0, 1, 2, 3, 4, 2][(i ~/ 5) % 7];
      } else {
        map[date] = [0, 0, 0, 1, 2, 1, 3][(i ~/ 7) % 7];
      }
    }
    
    return map;
  }

  static final contributionStats = {
    'currentStreak': 12,
    'longestStreak': 47,
    'totalContributions': 847,
    'thisWeek': 18,
    'thisMonth': 72,
    'thisYear': 847,
  };

  static final List<Map<String, dynamic>> repositories = [
    {
      'name': 'olc-app',
      'description': 'One Last Commit - GitHub activity tracker',
      'language': 'Dart',
      'stars': 28,
      'forks': 5,
      'updatedAt': DateTime.now().subtract(const Duration(hours: 2)),
    },
    {
      'name': 'portfolio',
      'description': 'Personal portfolio website',
      'language': 'TypeScript',
      'stars': 15,
      'forks': 2,
      'updatedAt': DateTime.now().subtract(const Duration(hours: 8)),
    },
    {
      'name': 'backend-api',
      'description': 'RESTful API for various projects',
      'language': 'Python',
      'stars': 42,
      'forks': 12,
      'updatedAt': DateTime.now().subtract(const Duration(days: 1)),
    },
    {
      'name': 'flutter-components',
      'description': 'Reusable Flutter widget library',
      'language': 'Dart',
      'stars': 156,
      'forks': 34,
      'updatedAt': DateTime.now().subtract(const Duration(days: 3)),
    },
  ];
}
