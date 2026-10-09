import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/storage/secure_storage_service.dart';
import '../core/theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    await Future.delayed(const Duration(seconds: 2));
    final isDeployed = await SecureStorageService.isDeployed();

    if (!mounted) return;

    if (isDeployed) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [AppTheme.goldLight, AppTheme.goldDark],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.goldPrimary.withValues(alpha: 0.35),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                size: 52,
                color: AppTheme.bgDark,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'مولد ريلز القرآن الكريم',
              style: GoogleFonts.cairo(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.goldLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'صدقة جارية مدى الحياة 🌿',
              style: GoogleFonts.amiri(
                fontSize: 18,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.goldPrimary),
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}
