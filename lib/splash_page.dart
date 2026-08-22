import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'main.dart';
import 'mixpanel_service.dart';
import 'dashboard_page.dart';
import 'splash_navigating_page.dart';
import 'onboard/onboard_intro.dart';
import 'onboard/onboard_paywall.dart';
import 'onboard/onboard_answers.dart';

// BUILD 29 — Splash routing, revised so casual/free-info visitors
// never hit the access-code wall.
//
// Three paths:
//   purchased              → DashboardPage
//   everyone else          → OnboardIntro (the funnel), every launch,
//                             no run cap
//   long-press splash logo → access-code prompt (DEBUG ONLY — see
//                             note below), independent of run count
//
// PREVIOUSLY: after kMaxFreeRuns onboarding runs, this page would
// interrupt with an access-code prompt before falling through to
// OnboardPaywall on a wrong/blank/dismissed entry. That wall was
// catching casual visitors who just wanted free information and had
// no intent to buy yet — SpOn_Splash_Route funnel data showed people
// bailing right around there. DECIDED (per earlier discussion): drop
// the run-count trigger entirely — unlimited free re-runs of the
// funnel, since the paywall itself is the real gate, not repeat
// exposure to the pitch. Free attempts counter (kOnboardingRunsKey)
// is still incremented in OnboardPaywall.initState and still useful
// as an analytics signal — just no longer drives routing here.
//
// This removed Gerry's only way to reach the access-code prompt (it
// was previously the run-count trigger itself), so a long-press on
// the splash logo now opens the same prompt directly, independent of
// run count — this is the new/only way in.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const String _seenSplashPrefKey = 'has_seen_splash_before';

  // Access code. Correct entry → SplashNavigatingPage (debug menu).
  // Anything else, blank, or dismissed → dialog just closes, normal
  // splash countdown/navigation continues underneath if it hasn't
  // already fired.
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

  // Guards against the auto-navigate firing after a long-press has
  // already taken the user down the debug path.
  bool _navigated = false;

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
    setState(() => _totalHoldSeconds = holdSeconds);
    _startDisplayTicker();
  }

  // FIXED — the ticker is now the SINGLE source of truth for both the
  // visible countdown and the auto-navigate trigger (previously a
  // separate Future.delayed(holdSeconds) fired from initState via
  // addPostFrameCallback, completely independent of this ticker and
  // of whether the debug access-code dialog was open). That meant a
  // long-press on the logo opened the dialog, but the original timer
  // kept running underneath — if typing the code took longer than the
  // 5-8s hold, _navigate() fired and pushed OnboardIntro/Dashboard
  // UNDER the still-open dialog, and by the time a correct code was
  // entered, _navigated was already true so _debugEntry bailed and did
  // nothing. Symptom: "the dialog opens, but I don't have time to type
  // the password, so it just goes to the onboarding funnel."
  //
  // Canceling this ticker (e.g. while the dialog is open) now genuinely
  // pauses the hold, not just the on-screen number. Resuming just
  // restarts this same timer; it picks up from whatever _secondsElapsed
  // already reached, it doesn't reset.
  void _startDisplayTicker() {
    _displayTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final total = _totalHoldSeconds;
      if (total != null && _secondsElapsed + 1 >= total) {
        _displayTicker?.cancel();
        setState(() => _secondsElapsed = total);
        _navigate();
        return;
      }
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

  Future<void> _navigate() async {
    final state = AppState();

    if (!mounted || _navigated) return;

    // Clear stale debug state.
    //
    // FIXED: this used to call state.reset(), which looks like it
    // should clear hasUnlockedApp — but AppState.reset() deliberately
    // SAVES hasUnlockedApp/purchaseType/purchaseDate before wiping
    // anything and RESTORES them at the end (so a normal progress
    // reset never accidentally un-purchases a real paying user). That
    // makes reset() a no-op for exactly the fields this guard is
    // trying to clear — a debug-forced hasUnlockedApp (set via
    // SplashNavigatingPage's force-unlock button, which never sets a
    // purchaseDate) would survive reset() untouched, and Path 1 below
    // would then route straight to Dashboard on every future launch,
    // permanently skipping this page's own routing entirely. Clear
    // the fields directly instead.
    if (state.hasUnlockedApp && state.purchaseDate == null) {
      state.hasUnlockedApp = false;
      state.purchaseType = PurchaseType.none;
      await AppStatePersistence.save();
    }
    if (!mounted || _navigated) return;

    // ── Path 1: purchased and active → Dashboard ─────────────────────
    // Checked FIRST so a paying customer never sees the funnel again.
    if (state.hasUnlockedApp && !state.isExpired) {
      _navigated = true;
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
    if (!mounted || _navigated) return;

    // ── Path 2: everyone else → funnel, every time ────────────────────
    // No run cap. The run counter (kOnboardingRunsKey) still increments
    // in OnboardPaywall.initState purely as an analytics signal — it no
    // longer gates anything here.
    _navigated = true;
    OnboardingAnswers.instance.reset();
    final prefs = await SharedPreferences.getInstance();
    final runs = prefs.getInt(kOnboardingRunsKey) ?? 0;
    MixpanelService.instance.track(
      'SpOn_Splash_Route',
      properties: {'app_name': 'SP', 'path': 'free_attempt', 'runs': runs},
    );
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OnboardIntro()),
    );
  }

  /// Long-press on the splash logo — the only remaining way to reach
  /// the debug access-code prompt, independent of run count.
  ///
  /// Stops the hold timer the instant the dialog opens (see
  /// _startDisplayTicker — canceling it pauses both the visible
  /// countdown and the auto-navigate trigger together) so a slow typer
  /// never gets yanked into the funnel mid-entry. If the code turns out
  /// wrong/blank/dismissed, the timer resumes from wherever it left
  /// off rather than restarting from zero.
  Future<void> _debugEntry() async {
    if (_navigated) return;
    _displayTicker?.cancel();

    final entered = await _promptAccessCode();
    if (!mounted || _navigated) return;

    if (entered == _accessCode) {
      _navigated = true;
      OnboardingAnswers.instance.reset();
      MixpanelService.instance.track(
        'SpOn_Splash_Route',
        properties: {'app_name': 'SP', 'path': 'debug_nav_longpress'},
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SplashNavigatingPage()),
      );
      return;
    }

    // Wrong/blank/dismissed: resume the paused timer from where it
    // left off — normal routing proceeds once it reaches the hold
    // duration, same as if the dialog had never opened.
    if (!_navigated) _startDisplayTicker();
  }

  /// Shows a modal asking for the access code. Returns the entered
  /// string, or null if dismissed.
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
              GestureDetector(
                onLongPress: _debugEntry,
                child: Image.asset('Assets/splash.png', width: 80, height: 80),
              ),
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

              // TEMP DEBUG (Aug 2026) \u2014 shows how long each pre-runApp
              // startup step took (or if it timed out), so a hang before
              // this page renders is visible without a USB debug session.
              // Only appears if this page actually gets to build, which
              // it now always should since every step ahead of it is
              // timeout-capped. Remove alongside startupDiagnostics/
              // _timed in main.dart once Android startup is confirmed
              // reliably fast.
              const SizedBox(height: 18),
              Text(
                '[DEBUG]\n${startupDiagnostics.join('\n')}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0x99F0EDE8),
                  fontSize: 9,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
