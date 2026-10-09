import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_constants.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/theme/app_theme.dart';
import '../models/github_user.dart';
import '../services/github_service.dart';
import '../services/youtube_oauth_service.dart';
import 'dashboard_screen.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _currentStep = 0;

  // Controllers
  final _ytClientIdController = TextEditingController();
  final _ytClientSecretController = TextEditingController();
  final _ytRefreshTokenController = TextEditingController();

  final _githubTokenController = TextEditingController();
  final _repoNameController = TextEditingController(text: AppConstants.defaultTargetRepoName);
  final _pexelsKeyController = TextEditingController();

  // State
  GithubUser? _verifiedUser;
  bool _isVerifyingGithub = false;
  bool _isAuthenticating = false;
  bool _isDeploying = false;
  String _deployStepText = '';
  double _deployProgress = 0.0;

  @override
  void dispose() {
    _ytClientIdController.dispose();
    _ytClientSecretController.dispose();
    _ytRefreshTokenController.dispose();
    _githubTokenController.dispose();
    _repoNameController.dispose();
    _pexelsKeyController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Runs Google's OAuth2 flow inside the app and auto-fills the refresh token
  /// field, so the user never has to extract it manually from a desktop.
  Future<void> _signInWithGoogle() async {
    final clientId = _ytClientIdController.text.trim();
    final clientSecret = _ytClientSecretController.text.trim();

    if (clientId.isEmpty || clientSecret.isEmpty) {
      _showSnackbar('أدخل Client ID و Client Secret أولاً (من Google Cloud Console).',
          isError: true);
      return;
    }

    setState(() => _isAuthenticating = true);
    try {
      final refreshToken = await YouTubeOAuthService.fetchRefreshToken(
        clientId: clientId,
        clientSecret: clientSecret,
      );

      if (refreshToken == null || refreshToken.isEmpty) {
        _showSnackbar('تم إلغاء تسجيل الدخول أو لم يصل رمز التحديث. حاول مرة أخرى.',
            isError: true);
        return;
      }

      _ytRefreshTokenController.text = refreshToken;
      _showSnackbar('✅ تم استخراج رمز التحديث الدائم تلقائياً! يمكنك المتابعة الآن.');
    } catch (e) {
      _showSnackbar(
        'فشل تسجيل الدخول: ${e.toString().replaceAll('Exception: ', '')}\n'
        'تأكد من إضافة رابط إعادة التوجيه في Google Cloud Console.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  Future<void> _verifyGithub() async {
    final token = _githubTokenController.text.trim();
    if (token.isEmpty) {
      _showSnackbar('يرجى إدخال رمز الوصول (GitHub Token)', isError: true);
      return;
    }

    setState(() => _isVerifyingGithub = true);
    try {
      final user = await GithubService.verifyTokenAndGetUser(token);
      setState(() {
        _verifiedUser = user;
        _isVerifyingGithub = false;
      });
      _showSnackbar('تم التحقق بنجاح! أهلاً بك يا ${user.name ?? user.login}');
    } catch (e) {
      setState(() => _isVerifyingGithub = false);
      _showSnackbar(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? AppTheme.statusError : AppTheme.statusSuccess,
      ),
    );
  }

  Future<void> _executeDeployment() async {
    final ytClientId = _ytClientIdController.text.trim();
    final ytClientSecret = _ytClientSecretController.text.trim();
    final ytRefreshToken = _ytRefreshTokenController.text.trim();
    final ghToken = _githubTokenController.text.trim();
    final repoName = _repoNameController.text.trim().isEmpty 
        ? AppConstants.defaultTargetRepoName 
        : _repoNameController.text.trim();
    final pexelsKey = _pexelsKeyController.text.trim();

    if (ytClientId.isEmpty || ytClientSecret.isEmpty || ytRefreshToken.isEmpty) {
      _showSnackbar('يرجى إكمال بيانات يوتيوب (الخطوة 1)', isError: true);
      setState(() => _currentStep = 0);
      return;
    }

    if (ghToken.isEmpty || _verifiedUser == null) {
      _showSnackbar('يرجى التحقق من حساب GitHub أولاً (الخطوة 2)', isError: true);
      setState(() => _currentStep = 1);
      return;
    }

    setState(() {
      _isDeploying = true;
      _deployProgress = 0.1;
      _deployStepText = 'جاري الاتصال بـ GitHub وتجهيز السيرفر...';
    });

    try {
      final owner = _verifiedUser!.login;

      // 1. Create Repo from Template
      setState(() {
        _deployProgress = 0.3;
        _deployStepText = 'إنشاء المستودع السحابي الخاص بك من القالب...';
      });
      final actualRepoName = await GithubService.createRepoFromTemplate(
        token: ghToken,
        templateOwner: AppConstants.defaultTemplateOwner,
        templateRepo: AppConstants.defaultTemplateRepo,
        targetRepoName: repoName,
      );

      // 1b. Discover the repository's real default branch (main vs master) and
      //     remember it so every later dispatch targets the correct branch.
      setState(() {
        _deployProgress = 0.4;
        _deployStepText = 'تحديد الفرع الافتراضي للمستودع...';
      });
      // Allow GitHub a few seconds to finish provisioning the new repository.
      await Future.delayed(const Duration(seconds: 3));

      final defaultBranch = await GithubService.getRepoDefaultBranch(
        token: ghToken,
        owner: owner,
        repo: actualRepoName,
      );
      await SecureStorageService.saveDefaultBranch(defaultBranch);

      // 1c. Verify GitHub Actions is enabled; warn (without blocking) if not.
      final actionsEnabled = await GithubService.isActionsEnabled(
        token: ghToken,
        owner: owner,
        repo: actualRepoName,
      );
      if (!actionsEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            content: Text(
              '⚠️ يجب تفعيل GitHub Actions على المستودع $actualRepoName ليعمل النشر التلقائي. '
              'من GitHub: Settings → Actions → General → Allow all actions.',
              style: GoogleFonts.cairo(color: Colors.white),
            ),
            backgroundColor: AppTheme.statusWarning,
          ),
        );
      }

      // 2. Fetch Public Key for Libsodium
      setState(() {
        _deployProgress = 0.5;
        _deployStepText = 'جلب مفتاح التشفير العام للمستودع...';
      });

      final keyData = await GithubService.getRepoPublicKey(
        token: ghToken,
        owner: owner,
        repo: actualRepoName,
      );
      final keyId = keyData['key_id']!;
      final base64Key = keyData['key']!;

      // 3. Encrypt and Inject Secrets
      setState(() {
        _deployProgress = 0.7;
        _deployStepText = 'تشفير وحقن الأسرار بـ Libsodium SealedBox بأمان...';
      });

      await GithubService.injectSecret(
        token: ghToken,
        owner: owner,
        repo: actualRepoName,
        secretName: AppConstants.secretYoutubeClientId,
        secretValue: ytClientId,
        keyId: keyId,
        base64PublicKey: base64Key,
      );

      await GithubService.injectSecret(
        token: ghToken,
        owner: owner,
        repo: actualRepoName,
        secretName: AppConstants.secretYoutubeClientSecret,
        secretValue: ytClientSecret,
        keyId: keyId,
        base64PublicKey: base64Key,
      );

      await GithubService.injectSecret(
        token: ghToken,
        owner: owner,
        repo: actualRepoName,
        secretName: AppConstants.secretYoutubeRefreshToken,
        secretValue: ytRefreshToken,
        keyId: keyId,
        base64PublicKey: base64Key,
      );

      if (pexelsKey.isNotEmpty) {
        await GithubService.injectSecret(
          token: ghToken,
          owner: owner,
          repo: actualRepoName,
          secretName: AppConstants.secretPexelsApiKey,
          secretValue: pexelsKey,
          keyId: keyId,
          base64PublicKey: base64Key,
        );
      }

      // 4. Trigger First Test Workflow Run
      setState(() {
        _deployProgress = 0.9;
        _deployStepText = 'إطلاق أول ريل تجريبي والتأكد من تفعيل الأتمتة...';
      });

      await GithubService.triggerWorkflowDispatch(
        token: ghToken,
        owner: owner,
        repo: actualRepoName,
        workflowFileName: AppConstants.workflowFileName,
        branch: defaultBranch,
      );

      // 5. Save Credentials to Local Secure Storage
      await SecureStorageService.saveGithubToken(ghToken);
      await SecureStorageService.saveGithubUser(owner);
      await SecureStorageService.saveTargetRepo(actualRepoName);
      await SecureStorageService.saveYouTubeCredentials(
        clientId: ytClientId,
        clientSecret: ytClientSecret,
        refreshToken: ytRefreshToken,
      );
      if (pexelsKey.isNotEmpty) {
        await SecureStorageService.savePexelsKey(pexelsKey);
      }
      await SecureStorageService.setDeployed(true);

      setState(() {
        _deployProgress = 1.0;
        _deployStepText = '🎉 اكتمل الإطلاق بنجاح!';
      });

      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      setState(() => _isDeploying = false);
      _showSnackbar('حدث خطأ أثناء الإطلاق: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('معالج الإعداد والربط السريع'),
      ),
      body: _isDeploying ? _buildDeployingView() : _buildWizardView(),
    );
  }

  Widget _buildDeployingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.goldPrimary.withValues(alpha: 0.15),
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.goldLight),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'جاري بناء قناتك السحابية 🌿',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.goldLight,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _deployStepText,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _deployProgress,
                minHeight: 8,
                backgroundColor: AppTheme.bgCard,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.goldPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWizardView() {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.goldPrimary,
              onSurface: AppTheme.textPrimary,
            ),
      ),
      child: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepTapped: (step) => setState(() => _currentStep = step),
        onStepContinue: () {
          if (_currentStep < 2) {
            setState(() => _currentStep += 1);
          } else {
            _executeDeployment();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: Text(
                      _currentStep == 2 ? '🚀 إطلاق القناة الآن' : 'التالي',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: details.onStepCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: BorderSide(color: AppTheme.goldPrimary.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    child: Text('السابق', style: GoogleFonts.cairo()),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: Text('يوتيوب', style: GoogleFonts.cairo(fontSize: 12)),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _buildStepYouTube(),
          ),
          Step(
            title: Text('GitHub', style: GoogleFonts.cairo(fontSize: 12)),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _buildStepGitHub(),
          ),
          Step(
            title: Text('الإطلاق', style: GoogleFonts.cairo(fontSize: 12)),
            isActive: _currentStep >= 2,
            content: _buildStepLaunch(),
          ),
        ],
      ),
    );
  }

  void _copyRedirectUri() {
    Clipboard.setData(const ClipboardData(text: AppConstants.oauthRedirectUri));
    _showSnackbar('✅ تم نسخ رابط إعادة التوجيه إلى الحافظة بنجاح!');
  }

  void _showGoogleCloudGuideDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.goldPrimary.withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: AppTheme.goldLight),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'دليل استخراج مفاتيح جوجل بسهولة',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.goldLight,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGuideStep('1', 'افتح Google Cloud Console وأنشئ مشروعاً جديداً باسم (Quran Reels).'),
              _buildGuideStep('2', 'ادخل إلى APIs & Services ثم Library وابحث عن (YouTube Data API v3) وقم بتفعيلها.'),
              _buildGuideStep('3', 'من شاشة Credentials، أنشئ OAuth client ID من نوع Desktop app.'),
              _buildGuideStep('4', 'في شاشة OAuth Consent Screen، اضغط Publish App ليبقى التوكن نشطاً مدى الحياة دون توقف.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('رابط إعادة التوجيه المطلوب إضافته:', style: GoogleFonts.cairo(fontSize: 11, color: AppTheme.goldLight, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    SelectableText(
                      AppConstants.oauthRedirectUri,
                      style: GoogleFonts.cairo(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _copyRedirectUri();
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.bgDark),
                        label: Text('نسخ الرابط الآن', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openUrl(AppConstants.tutorialVideoUrl);
                  },
                  icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.goldLight, size: 20),
                  label: Text('شاهد فيديو الشرح الكامل (مصطفى بحيري)', style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.goldLight, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.goldPrimary),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('حسناً، فهمت', style: GoogleFonts.cairo(color: AppTheme.goldLight, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: AppTheme.goldPrimary,
            child: Text(num, style: GoogleFonts.cairo(fontSize: 11, color: AppTheme.bgDark, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.textPrimary, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepYouTube() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Helper Action Banner with Tutorial Video and Step Guide
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.goldPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.video_library_rounded, color: AppTheme.goldLight, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'شرح فيديو تفصيلي خطوة بخطوة من مصطفى بحيري (قناة البحيري)',
                      style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.goldLight),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openUrl(AppConstants.tutorialVideoUrl),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.goldPrimary,
                        foregroundColor: AppTheme.bgDark,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text('مشاهدة فيديو الشرح', style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showGoogleCloudGuideDialog,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.goldLight,
                        side: const BorderSide(color: AppTheme.goldPrimary),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.help_outline_rounded, size: 16),
                      label: Text('دليل الـ 4 خطوات', style: GoogleFonts.cairo(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ytClientIdController,
          decoration: const InputDecoration(
            labelText: 'Client ID (معرف العميل)',
            hintText: 'xxxxxx.apps.googleusercontent.com',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ytClientSecretController,
          decoration: const InputDecoration(
            labelText: 'Client Secret (السر)',
            hintText: 'GOCSPX-xxxxxx',
          ),
        ),
        const SizedBox(height: 18),
        // One-tap Google sign-in: fills the refresh token automatically.
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isAuthenticating ? null : _signInWithGoogle,
            icon: _isAuthenticating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.bgDark,
                    ),
                  )
                : const Icon(Icons.login_rounded, color: AppTheme.bgDark),
            label: Text(
              _isAuthenticating
                  ? 'في انتظار تسجيل الدخول...'
                  : '🔐 تسجيل الدخول بحساب جوجل (استخراج تلقائي للرمز)',
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.bgDark,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Redirect URI the user must whitelist once in Google Cloud Console.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'خطوة لمرة واحدة في Google Cloud:',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.goldLight,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _copyRedirectUri,
                    icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.goldLight),
                    label: Text('نسخ الرابط', style: GoogleFonts.cairo(fontSize: 11, color: AppTheme.goldLight)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 24)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SelectableText(
                AppConstants.oauthRedirectUri,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppTheme.goldPrimary.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'أضف هذا الرابط إلى Authorized redirect URIs لعميل OAuth (من نوع Desktop app)، '
                'واحرص على ضبط شاشة الموافقة على In Production.',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ytRefreshTokenController,
          decoration: const InputDecoration(
            labelText: 'Refresh Token (رمز التحديث الدائم)',
            hintText: 'يُملأ تلقائياً بعد تسجيل الدخول أعلاه',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => _openUrl(AppConstants.googleCloudConsoleUrl),
              icon: const Icon(Icons.open_in_new_rounded, size: 16, color: AppTheme.goldLight),
              label: Text(
                'فتح Google Cloud Console',
                style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.goldLight),
              ),
            ),
            TextButton.icon(
              onPressed: _showGoogleCloudGuideDialog,
              icon: const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.goldLight),
              label: Text(
                'الدليل الإرشادي',
                style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.goldLight),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepGitHub() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'أدخل رمز الوصول الشخصي (GitHub Personal Access Token):',
          style: GoogleFonts.cairo(fontSize: 13, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _githubTokenController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'GitHub Token',
            hintText: 'ghp_xxxxxxxxxxxx',
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isVerifyingGithub ? null : _verifyGithub,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.bgCardHover,
                  foregroundColor: AppTheme.goldLight,
                ),
                icon: _isVerifyingGithub
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user_rounded, size: 18),
                label: Text('فحص الرمز', style: GoogleFonts.cairo(fontSize: 13)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openUrl(AppConstants.githubNewTokenUrl),
                icon: const Icon(Icons.add_link_rounded, size: 18, color: AppTheme.goldLight),
                label: Text('توليد رمز جديد', style: GoogleFonts.cairo(fontSize: 13, color: AppTheme.goldLight)),
              ),
            ),
          ],
        ),
        if (_verifiedUser != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.statusSuccess.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.statusSuccess.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: _verifiedUser!.avatarUrl != null
                      ? NetworkImage(_verifiedUser!.avatarUrl!)
                      : null,
                  child: _verifiedUser!.avatarUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _verifiedUser!.name ?? _verifiedUser!.login,
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '@${_verifiedUser!.login}',
                        style: GoogleFonts.cairo(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: AppTheme.statusSuccess),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepLaunch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _repoNameController,
          decoration: const InputDecoration(
            labelText: 'اسم المستودع السحابي في حسابك',
            hintText: 'quran-reels-channel-auto',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pexelsKeyController,
          decoration: const InputDecoration(
            labelText: 'مفتاح Pexels للصور (اختياري)',
            hintText: 'في حال تركه فارغاً سيعمل الشفق وسماء النجوم تلقائياً',
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ماذا سيحدث عند الضغط على "إطلاق القناة"؟',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppTheme.goldLight),
              ),
              const SizedBox(height: 8),
              _buildCheckItem('نسخ كود المونتاج بالكامل إلى حسابك على GitHub.'),
              _buildCheckItem('تشفير مفاتيحك بـ Libsodium وحقنها في GitHub Secrets.'),
              _buildCheckItem('تفعيل النشر التلقائي 4 مرات يومياً مدى الحياة.'),
              _buildCheckItem('إنتاج ونشر أول ريل قرآني تجريبي للتأكد من الجاهزية.'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.bgDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.favorite_rounded, color: AppTheme.goldLight, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'فكرة وتطوير: مصطفى بحيري (${AppConstants.channelName}) — صدقة جارية 🌿',
                  style: GoogleFonts.cairo(fontSize: 11, color: AppTheme.goldLight),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openUrl(AppConstants.channelUrl),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 30),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.subscriptions_rounded, size: 13, color: Colors.white),
                label: Text(
                  'اشترك بقناتي',
                  style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.goldPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
