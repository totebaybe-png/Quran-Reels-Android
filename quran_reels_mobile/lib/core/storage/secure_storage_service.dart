import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
  );

  // GitHub Access Token
  static Future<void> saveGithubToken(String token) async =>
      await _storage.write(key: AppConstants.keyGithubToken, value: token);

  static Future<String?> getGithubToken() async =>
      await _storage.read(key: AppConstants.keyGithubToken);

  // GitHub Username
  static Future<void> saveGithubUser(String user) async =>
      await _storage.write(key: AppConstants.keyGithubUser, value: user);

  static Future<String?> getGithubUser() async =>
      await _storage.read(key: AppConstants.keyGithubUser);

  // Target Repository Name
  static Future<void> saveTargetRepo(String repo) async =>
      await _storage.write(key: AppConstants.keyTargetRepo, value: repo);

  static Future<String?> getTargetRepo() async =>
      await _storage.read(key: AppConstants.keyTargetRepo);

  // YouTube OAuth Credentials
  static Future<void> saveYouTubeCredentials({
    required String clientId,
    required String clientSecret,
    required String refreshToken,
  }) async {
    await _storage.write(key: AppConstants.keyYoutubeClientId, value: clientId);
    await _storage.write(key: AppConstants.keyYoutubeClientSecret, value: clientSecret);
    await _storage.write(key: AppConstants.keyYoutubeRefreshToken, value: refreshToken);
  }

  static Future<Map<String, String?>> getYouTubeCredentials() async {
    return {
      'clientId': await _storage.read(key: AppConstants.keyYoutubeClientId),
      'clientSecret': await _storage.read(key: AppConstants.keyYoutubeClientSecret),
      'refreshToken': await _storage.read(key: AppConstants.keyYoutubeRefreshToken),
    };
  }

  // Pexels API Key
  static Future<void> savePexelsKey(String key) async =>
      await _storage.write(key: AppConstants.keyPexelsKey, value: key);

  static Future<String?> getPexelsKey() async =>
      await _storage.read(key: AppConstants.keyPexelsKey);

  // Deployment Status
  static Future<void> setDeployed(bool deployed) async =>
      await _storage.write(key: AppConstants.keyIsDeployed, value: deployed.toString());

  static Future<bool> isDeployed() async {
    final val = await _storage.read(key: AppConstants.keyIsDeployed);
    return val == 'true';
  }

  // Repository default branch (fetched from GitHub, never hardcoded)
  static Future<void> saveDefaultBranch(String branch) async =>
      await _storage.write(key: AppConstants.keyDefaultBranch, value: branch);

  static Future<String?> getDefaultBranch() async =>
      await _storage.read(key: AppConstants.keyDefaultBranch);

  // Clear all for reset
  static Future<void> clearAll() async => await _storage.deleteAll();
}
