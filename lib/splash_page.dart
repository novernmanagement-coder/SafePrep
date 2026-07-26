import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'mixpanel_service.dart';
import 'dashboard_page.dart';
import 'onboard/onboard_intro.dart';
import 'onboard/onboard_paywall.dart';

// BUILD 27 — Simplified routing.
//
// Two paths, nothing else:
//   purchased  → DashboardPage
//   not purchased → OnboardIntro (replays every launch until they buy)
//
// The old preview/trial/cinematic flow is dead. The onboarding funnel
// IS the trial — no free-roam dashboard, no 30-minute timer, no
// PreviewCinematicSplash.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const String _seenSplashPrefKey = 'has_seen_splash_before';

  static const int _firstLaunchHoldSeconds = 15;
  static const int _returningHoldSeconds = 5;
  static const int _orientationSeconds = 2;

  Timer? _displayTicker;
  int _secondsElapsed = 0;
  int? _totalHoldSeconds;
  bool _isFirstLaunch = true;

  @override
  void initState() {
    super.initState();
    _initHoldDuration();
  }

  Future<void> _initHoldDuration() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenBefore = prefs.getBool(_seenSplashPrefKey) ?? false;
    final holdSeconds = hasSeenBefore
        ? _returningHoldSeconds
        : _firstLaunchHoldSeconds;

    if (!hasSeenBefore) {
      await prefs.setBool(_seenSplashPrefKey, true);
    }

    if (!mounted) return;
    setState(() {
      _totalHoldSeconds = holdSeconds;
      _isFirstLaunch = !hasSeenBefore;
    });
    _startDisplayTicker();
    WidgetsBinding.instance.addPostFrameCallback((_) => _navigate(holdSeconds));
  }

  void _startDisplayTicker() {
    _displayTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsElapsed++);
    });
  }

  @override
  void dispose() {
    _displayTicker?.cancel();
    super.dispose();
  }

  int get _countdownRemaining {
    final total = _totalHoldSeconds ?? _returningHoldSeconds;
    final remaining = total - _secondsElapsed;
    return remaining.clamp(0, total - _orientationSeconds);
  }

  Future<void> _navigate(int holdSeconds) async {
    final state = AppState();

    await Future.delayed(Duration(seconds: holdSeconds));
    if (!mounted) return;

    // Clear stale debug state
    if (state.hasUnlockedApp && state.purchaseDate == null) {
      state.reset();
      await AppStatePersistence.delete();
    }
    if (!mounted) return;

    // ── Three paths ──────────────────────────────────────────────────
    //
    //   1. Purchased and active → Dashboard
    //   2. Already declined to limited Rapid Fire → decline page
    //      (purchase button + Rapid Fire + Student Presenter)
    //   3. First time / hasn't declined yet → full onboarding funnel
    //
    if (state.hasUnlockedApp && !state.isExpired) {
      MixpanelService.instance.track(
        'splash_route',
        properties: {'app_name': 'SP', 'path': 'purchased'},
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
      return;
    }

    if (state.hasUnlockedApp && state.isExpired) {
      state.hasUnlockedApp = false;
      AppStatePersistence.save();
    }
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasDeclined = prefs.getBool('has_declined_to_limited') ?? false;

    if (!mounted) return;

    if (hasDeclined) {
      MixpanelService.instance.track(
        'splash_route',
        properties: {'app_name': 'SP', 'path': 'returner_declined'},
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const OnboardPaywall(startOnDecline: true),
        ),
      );
    } else {
      MixpanelService.instance.track(
        'splash_route',
        properties: {'app_name': 'SP', 'path': 'fresh_onboarding'},
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardIntro()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showCountdown =
        _totalHoldSeconds != null && _secondsElapsed >= _orientationSeconds;

    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('Assets/splash.png', width: 80, height: 80),
              const SizedBox(height: 24),

              const Text(
                '100% Guaranteed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFB8860B),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pass the ServSafe\u00AE exam or your money back.\nWe\'ll have you ready in less than 4 hours.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.strongText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                _isFirstLaunch
                    ? 'A short diagnostic will show you exactly where you stand \u2014 and how little time it takes to close the gap.'
                    : 'Welcome back \u2014 your study plan is right where you left it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.subtleText,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 28),

              AnimatedOpacity(
                opacity: showCountdown ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  showCountdown
                      ? 'Initializing system $_countdownRemaining\u2026'
                      : ' ',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFB8860B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
