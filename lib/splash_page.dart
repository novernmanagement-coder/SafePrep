import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'mixpanel_service.dart';
import 'dashboard_page.dart';
import 'splash_navigating_page.dart';
import 'onboard/onboard_intro.dart';
import 'onboard/onboard_paywall.dart';
import 'onboard/onboard_answers.dart';

// BUILD 28 — Simplified routing, updated for the self-report redesign.
//
// Three paths:
//   purchased            → DashboardPage
//   wrong / no code       → OnboardPaywall
//   correct access code   → SplashNavigatingPage (DEBUG ONLY — see note
//                           below; was OnboardIntro before this change)
//
// The old preview/trial/cinematic flow is dead. The onboarding funnel
// IS the trial — no free-roam dashboard, no 30-minute timer, no
// PreviewCinematicSplash.
//
// The free-attempts counter (onboarding_runs_completed) used to be
// incremented inside OnboardReadiness, on the diagnostic verdict
// screen. That screen is gone in the self-report redesign, so the
// increment now happens when the user REACHES THE PAYWALL instead —
// that's the new equivalent of "completed a full run through the
// funnel." See OnboardPaywall.initState.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const String _seenSplashPrefKey = 'has_seen_splash_before';

  // Access code. Correct entry → SplashNavigatingPage (debug menu).
  // Anything else, blank, or dismissed → paywall.
  //
  // DEBUG ONLY — REMOVE BEFORE RELEASE. This access-code branch
  // normally routed to OnboardIntro (the real funnel). It's been
  // temporarily repointed at SplashNavigatingPage so the correct code
  // reaches the debug destination menu instead — StoreKit/IAP isn't
  // resolvable in this test environment, so the real purchase flow
  // can't always be reached normally. Revert the branch below (swap
  // SplashNavigatingPage back to OnboardIntro, drop the
  // splash_navigating_page.dart import) once the landing page is
  // locked and the real purchase → landing handoff has been verified.
  static const String _accessCode = 'Novern2026!';

  static const int _firstLaunchHoldSeconds = 8;
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

    // ── Path 1: purchased and active → Dashboard ─────────────────────
    // Checked FIRST so a paying customer never sees the access prompt.
    if (state.hasUnlockedApp && !state.isExpired) {
      MixpanelService.instance.track(
        'SpOn_Splash_Route',
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
    final runs = prefs.getInt(kOnboardingRunsKey) ?? 0;

    if (!mounted) return;

    // ── Free attempts ─────────────────────────────────────────────────
    // First two runs skip the access-code prompt entirely and drop
    // straight into the funnel. From the 3rd run on, the code is
    // required — wrong/blank/dismissed falls to the paywall.
    if (runs < kMaxFreeRuns) {
      OnboardingAnswers.instance.reset();
      MixpanelService.instance.track(
        'SpOn_Splash_Route',
        properties: {'app_name': 'SP', 'path': 'free_attempt', 'runs': runs},
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardIntro()),
      );
      return;
    }

    // ── Access-code fork ─────────────────────────────────────────────
    // Correct code → SplashNavigatingPage (DEBUG — see class-level
    // note). Anything else → paywall.
    final entered = await _promptAccessCode();
    if (!mounted) return;

    if (entered == _accessCode) {
      // Clear stale funnel data so each run starts clean.
      OnboardingAnswers.instance.reset();
      MixpanelService.instance.track(
        'SpOn_Splash_Route',
        properties: {'app_name': 'SP', 'path': 'debug_nav', 'runs': runs},
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SplashNavigatingPage()),
      );
    } else {
      MixpanelService.instance.track(
        'SpOn_Splash_Route',
        properties: {'app_name': 'SP', 'path': 'runs_exhausted', 'runs': runs},
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardPaywall()),
      );
    }
  }

  /// Shows a modal asking for the access code. Returns the entered
  /// string, or null if dismissed. A null / wrong return routes to the
  /// paywall.
  Future<String?> _promptAccessCode() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF13130F),
          title: const Text(
            'Access code',
            style: TextStyle(color: Color(0xFFF0EDE8), fontSize: 16),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            style: const TextStyle(color: Color(0xFFF0EDE8)),
            decoration: const InputDecoration(
              hintText: 'Enter code',
              hintStyle: TextStyle(color: Color(0x66F0EDE8)),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0x33D4AF37)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFD4AF37)),
              ),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text(
                'Continue',
                style: TextStyle(color: Color(0xFFD4AF37)),
              ),
            ),
          ],
        );
      },
    );
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
                'Pass the ServSafe\u00AE exam or your money back.\nWe will prepare you for the ServSafe exam.',
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
                'Tell us where you stand \u2014 we\u2019ll build your plan '
                'around it.',
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
