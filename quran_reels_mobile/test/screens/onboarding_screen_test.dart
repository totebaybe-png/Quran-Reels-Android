import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran_reels_mobile/screens/onboarding_screen.dart';
import 'package:quran_reels_mobile/screens/setup_wizard_screen.dart';

void main() {
  setUp(() {
    // Keep widget tests offline: never fetch font files over the network.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'renders the headline and CTA, and navigates to the setup wizard on tap',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: OnboardingScreen()),
      );

      expect(find.textContaining('أطلق قناتك القرآنية المؤتمتة'), findsOneWidget);
      expect(find.text('ابدأ الإعداد الآن (خطوتان فقط)'), findsOneWidget);

      await tester.tap(find.text('ابدأ الإعداد الآن (خطوتان فقط)'));
      await tester.pumpAndSettle();

      expect(find.byType(SetupWizardScreen), findsOneWidget);
    },
  );
}
