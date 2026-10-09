import 'package:flutter_appauth/flutter_appauth.dart';
import '../core/constants/app_constants.dart';

/// Runs Google's OAuth2 authorization-code flow *inside the app* so a normal
/// mobile user can obtain the long-lived [refresh token] that the GitHub
/// Actions bot needs to upload reels to their YouTube channel — no desktop
/// computer, no terminal, and no manual token extraction.
///
/// The user brings their *own* Google Cloud OAuth client (Client ID + Secret),
/// which is why the flow is configured dynamically instead of bundling secrets
/// in the app.
class YouTubeOAuthService {
  static const FlutterAppAuth _appAuth = FlutterAppAuth();

  /// Opens the Google sign-in/consent screen and returns the freshly issued
  /// refresh token, or null if the user cancelled the flow.
  ///
  /// Requirements the user must satisfy once in Google Cloud Console:
  /// 1. YouTube Data API v3 enabled on the project.
  /// 2. OAuth client of type "Desktop app".
  /// 3. [AppConstants.oauthRedirectUri] added to Authorized redirect URIs.
  /// 4. OAuth consent screen set to "In production" (else refresh tokens
  ///    expire after 7 days).
  static Future<String?> fetchRefreshToken({
    required String clientId,
    required String clientSecret,
  }) async {
    final tokenResponse = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        clientId,
        AppConstants.oauthRedirectUri,
        clientSecret: clientSecret,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: AppConstants.googleAuthorizationEndpoint,
          tokenEndpoint: AppConstants.googleTokenEndpoint,
        ),
        scopes: AppConstants.googleScopes,
        // access_type=offline is mandatory for Google to issue a refresh token;
        // prompt=consent forces a fresh grant so a brand-new token is returned
        // even if the user signed in before.
        additionalParameters: const {'access_type': 'offline'},
        promptValues: const ['consent'],
      ),
    );

    return tokenResponse.refreshToken;
  }
}
