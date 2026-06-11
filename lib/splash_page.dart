import 'package:flutter/material.dart';
import 'constants.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'home_page.dart';
import 'intro_page.dart';
import 'preview/preview_cinematic_splash.dart';

// BUILD 26 — version 1.3.1+26 — Full page curriculum, navigation fix, fresh dashboard on first load
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const bool _debugBypassPreview = false;
  static const bool _debugShowPreview = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigate());
  }

  Future<void> _navigate() async {
    final state = AppState();

    // Minimum splash display time
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Clear stale debug state
    if (state.hasUnlockedApp && state.purchaseDate == null) {
      state.reset();
      await AppStatePersistence.delete();
    }

    if (_debugShowPreview) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PreviewCinematicSplash()),
      );
      return;
    }

    if (_debugBypassPreview) {
      state.hasUnlockedApp = true;
      state.purchaseType = PurchaseType.lifetime;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
      return;
    }

    if (state.hasUnlockedApp && state.isExpired) {
      state.hasUnlockedApp = false;
      AppStatePersistence.save();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PreviewCinematicSplash()),
      );
      return;
    }

    if (state.hasUnlockedApp) {
      if (!state.hasSeenIntro) {
        state.clearCurriculumProgress();
        state.hasSeenIntro = true;
        AppStatePersistence.save();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const IntroductoryPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PreviewCinematicSplash()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('Assets/splash.png', width: 80, height: 80),
            const SizedBox(height: 24),
            const Text(
              'Designed for you in every detail.',
              style: TextStyle(
                color: const Color(0xFFD4AF37),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
