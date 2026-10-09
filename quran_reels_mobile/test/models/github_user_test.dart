import 'package:flutter_test/flutter_test.dart';
import 'package:quran_reels_mobile/models/github_user.dart';

void main() {
  group('GithubUser', () {
    test('parses a complete API response', () {
      final user = GithubUser.fromJson({
        'login': 'octocat',
        'name': 'The Octocat',
        'avatar_url': 'https://avatars.githubusercontent.com/u/583231?v=4',
        'public_repos': 8,
      });

      expect(user.login, 'octocat');
      expect(user.name, 'The Octocat');
      expect(user.avatarUrl, isNotEmpty);
      expect(user.publicRepos, 8);
    });

    test('falls back safely when optional fields are absent', () {
      final user = GithubUser.fromJson({'login': 'ghost'});

      expect(user.login, 'ghost');
      expect(user.name, isNull);
      expect(user.avatarUrl, isNull);
      expect(user.publicRepos, 0);
    });
  });
}
