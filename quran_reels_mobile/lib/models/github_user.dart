class GithubUser {
  final String login;
  final String? name;
  final String? avatarUrl;
  final int publicRepos;

  GithubUser({
    required this.login,
    this.name,
    this.avatarUrl,
    required this.publicRepos,
  });

  factory GithubUser.fromJson(Map<String, dynamic> json) {
    return GithubUser(
      login: json['login'] ?? '',
      name: json['name'],
      avatarUrl: json['avatar_url'],
      publicRepos: json['public_repos'] ?? 0,
    );
  }
}
