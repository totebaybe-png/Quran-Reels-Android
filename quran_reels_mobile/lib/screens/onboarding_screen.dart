import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import 'setup_wizard_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Header Badge & Author Attribution
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.goldPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_rounded, color: AppTheme.goldLight, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'صدقة جارية | مصطفى بحيري (${AppConstants.channelName})',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.goldLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'أطلق قناتك القرآنية المؤتمتة\nفي أقل من دقيقتين',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'نظام سحابي ذكي ينتج وينشر مقاطع ريلز وشورتس القرآن الكريم تلقائياً 4 مرات يومياً بدون الحاجة لحاسوب أو إبقاء الهاتف مفتوحاً.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 30),
              // Feature Cards List
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: const [
                    _FeatureTile(
                      icon: Icons.cloud_done_rounded,
                      title: 'أتمتة سحابية مجانية مدى الحياة',
                      subtitle:
                          'النشر يعمل تلقائياً 4 مرات يومياً عبر سيرفرات GitHub السحابية حتى لو هاتفك مغلق تماماً.',
                    ),
                    SizedBox(height: 14),
                    _FeatureTile(
                      icon: Icons.security_rounded,
                      title: 'أمان وتشفير عالي (Zero Leakage)',
                      subtitle:
                          'مفاتيحك وبيانات قناتك تُشفر محلياً بخوارزمية Libsodium ولا تمر أبداً على أي سيرفر وسيط.',
                    ),
                    SizedBox(height: 14),
                    _FeatureTile(
                      icon: Icons.movie_filter_rounded,
                      title: 'محتوى نقي 100% وطبيعة خلابة',
                      subtitle:
                          'فيديوهات خالية تماماً من الوجوه أو البشر، مع تلاوات خاشعة لأشهر القراء والرسم العثماني.',
                    ),
                  ],
                ),
              ),
              // Action Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SetupWizardScreen()),
                    );
                  },
                  icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.bgDark),
                  label: Text(
                    'ابدأ الإعداد الآن (خطوتان فقط)',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.bgDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => _openUrl(AppConstants.tutorialVideoUrl),
                    icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.goldLight, size: 18),
                    label: Text(
                      'فيديو الشرح',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppTheme.goldLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text('•', style: TextStyle(color: AppTheme.goldPrimary.withValues(alpha: 0.5))),
                  ),
                  TextButton.icon(
                    onPressed: () => _openUrl(AppConstants.channelUrl),
                    icon: const Icon(Icons.subscriptions_rounded, color: Colors.redAccent, size: 18),
                    label: Text(
                      'اشترك بقناة المطور (@behairy10)',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppTheme.goldLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.goldPrimary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.goldLight, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
