import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_constants.dart';

/// Runs Google's OAuth2 authorization-code flow using a local loopback server
/// (RFC 8252 for Desktop / Native apps) inside the app, so a mobile user
/// can obtain the long-lived [refresh token] without needing a computer.
///
/// Using loopback (127.0.0.1) solves the "Error 400: redirect_uri_mismatch"
/// because Google Cloud Console natively supports loopback URIs for "Desktop app"
/// credentials without requiring manual whitelist registration.
class YouTubeOAuthService {
  /// Opens the Google sign-in screen in the browser, listens on a local
  /// loopback port, exchanges the authorization code for tokens, and returns
  /// the freshly issued refresh token.
  static Future<String?> fetchRefreshToken({
    required String clientId,
    required String clientSecret,
  }) async {
    HttpServer? server;
    StreamSubscription<HttpRequest>? sub;
    final completer = Completer<String?>();

    try {
      // 1. Bind to loopback interface on port 8989, or an ephemeral port if occupied
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8989);
      } catch (_) {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      }

      final port = server.port;
      final redirectUri = 'http://127.0.0.1:$port';

      // 2. Listen for the callback from Google
      sub = server.listen((HttpRequest request) async {
        final uri = request.uri;
        final code = uri.queryParameters['code'];
        final error = uri.queryParameters['error'];

        final response = request.response;
        response.headers.contentType = ContentType.html;

        if (code != null) {
          response.write('''
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>تم تسجيل الدخول بنجاح</title>
  <style>
    body {
      background-color: #0A0A12;
      color: #FFFFFF;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Cairo", sans-serif;
      text-align: center;
      padding: 40px 20px;
      margin: 0;
    }
    .card {
      max-width: 420px;
      margin: 40px auto;
      background: #171726;
      border: 1px solid #D4AF37;
      border-radius: 16px;
      padding: 30px 20px;
      box-shadow: 0 10px 30px rgba(0,0,0,0.5);
    }
    h2 { color: #F4D06F; margin-top: 0; }
    p { color: #B0B0C4; font-size: 15px; line-height: 1.6; }
    .badge {
      display: inline-block;
      background: rgba(16, 185, 129, 0.2);
      color: #10B981;
      border: 1px solid #10B981;
      padding: 6px 16px;
      border-radius: 20px;
      font-weight: bold;
      margin-bottom: 16px;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">✓ نجاح الاتصال</div>
    <h2>تم استخراج الرمز بنجاح!</h2>
    <p>تم ربط حسابك بجوجل ويوتيوب بنجاح.<br>يمكنك الآن إغلاق هذا المتصفح والعودة لتطبيق <strong>ريلز القرآن</strong> للمتابعة.</p>
  </div>
</body>
</html>
''');
          await response.close();

          // 3. Exchange authorization code for refresh token
          try {
            final tokenResponse = await http.post(
              Uri.parse(AppConstants.googleTokenEndpoint),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: {
                'client_id': clientId,
                'client_secret': clientSecret,
                'code': code,
                'grant_type': 'authorization_code',
                'redirect_uri': redirectUri,
              },
            );

            if (tokenResponse.statusCode == 200) {
              final data = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
              final refreshToken = data['refresh_token'] as String?;
              if (!completer.isCompleted) {
                completer.complete(refreshToken);
              }
            } else {
              final errorBody = tokenResponse.body;
              String msg = 'فشل استبدال الرمز: $errorBody';
              try {
                final errorData = jsonDecode(errorBody);
                msg = errorData['error_description'] ?? errorData['error'] ?? msg;
              } catch (_) {}
              if (!completer.isCompleted) {
                completer.completeError(Exception(msg));
              }
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          }
        } else {
          response.write('''
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8">
  <title>إلغاء تسجيل الدخول</title>
  <body style="background:#0A0A12;color:#EF4444;text-align:center;padding:50px;font-family:sans-serif;">
    <h2>لم تكتمل عملية تسجيل الدخول</h2>
    <p style="color:#B0B0C4;">${error ?? 'تم إلغاء العملية أو رفض الإذن'}</p>
  </body>
</html>
''');
          await response.close();
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }

        await sub?.cancel();
        await server?.close(force: true);
      });

      // 4. Construct Google Auth URL
      final authUri = Uri.parse(AppConstants.googleAuthorizationEndpoint).replace(
        queryParameters: {
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'response_type': 'code',
          'scope': AppConstants.googleScopes.join(' '),
          'access_type': 'offline',
          'prompt': 'consent',
        },
      );

      // 5. Open in external browser (Chrome)
      final launched = await launchUrl(
        authUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await sub.cancel();
        await server.close(force: true);
        throw Exception('تعذر فتح متصفح الهاتف لتسجيل الدخول.');
      }

      // Timeout after 5 minutes
      return await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () async {
          await sub?.cancel();
          await server?.close(force: true);
          throw Exception('انتهت مهلة تسجيل الدخول (5 دقائق). يرجى المحاولة مرة أخرى.');
        },
      );
    } catch (e) {
      await sub?.cancel();
      await server?.close(force: true);
      rethrow;
    }
  }
}
