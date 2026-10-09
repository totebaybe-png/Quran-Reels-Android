class AppConstants {
  static const String appTitle = 'مولد ريلز القرآن';
  static const String appSubtitle = 'أتمتة سحابية لنشر القرآن الكريم 24/7 مدى الحياة';
  static const String appVersion = '1.0.0';
  static const String authorName = 'مصطفى بحيري';
  static const String channelName = 'قناة البحيري :behiry';
  static const String channelUrl = 'https://www.youtube.com/@behairy10';
  static const String tutorialVideoUrl = 'https://youtu.be/ozgBWYtWNLA';
  
  // GitHub Defaults
  static const String defaultTemplateOwner = 'totebaybe-png';
  static const String defaultTemplateRepo = 'Quran-Reels-Android';
  static const String defaultTargetRepoName = 'quran-reels-channel-auto';
  static const String workflowFileName = 'daily_quran_reel.yml';

  // Secret Names Expected by GitHub Actions
  static const String secretYoutubeClientId = 'YOUTUBE_CLIENT_ID';
  static const String secretYoutubeClientSecret = 'YOUTUBE_CLIENT_SECRET';
  static const String secretYoutubeRefreshToken = 'YOUTUBE_REFRESH_TOKEN';
  static const String secretPexelsApiKey = 'PEXELS_API_KEY';

  // Direct URLs for easy user onboarding
  static const String githubNewTokenUrl = 
      'https://github.com/settings/tokens/new?scopes=repo,workflow&description=Quran+Reels+Mobile+Orchestrator';
  static const String googleCloudConsoleUrl = 'https://console.cloud.google.com';
  static const String pexelsApiUrl = 'https://www.pexels.com/api/';

  // Storage Keys
  static const String keyGithubToken = 'sec_github_token';
  static const String keyGithubUser = 'sec_github_user';
  static const String keyTargetRepo = 'sec_target_repo';
  static const String keyYoutubeClientId = 'sec_yt_client_id';
  static const String keyYoutubeClientSecret = 'sec_yt_client_sec';
  static const String keyYoutubeRefreshToken = 'sec_yt_refresh_token';
  static const String keyPexelsKey = 'sec_pexels_key';
  static const String keyIsDeployed = 'sec_is_deployed';
  static const String keyLastRunTime = 'sec_last_run_time';
  static const String keyDefaultBranch = 'sec_default_branch';

  // OAuth (Google) deep-link scheme used by flutter_appauth. Must match the
  // intent-filter declared in android/app/src/main/AndroidManifest.xml and the
  // redirect URI the user whitelists in Google Cloud Console.
  static const String oauthRedirectScheme = 'com.quran.reels.orchestrator';
  static const String oauthRedirectUri = 'com.quran.reels.orchestrator:/oauth2redirect';

  // YouTube OAuth2 endpoints (Google's well-known discovery values).
  static const String googleAuthorizationEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const String googleTokenEndpoint =
      'https://oauth2.googleapis.com/token';
  static const List<String> googleScopes = [
    'https://www.googleapis.com/auth/youtube.upload',
    'https://www.googleapis.com/auth/userinfo.profile',
  ];
}
