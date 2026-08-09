import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'app_state.dart';
import 'dashboard_page.dart';
import 'fsme_post_purchase_landing.dart';
import 'home_page.dart';
import 'onboard/onboard_intro.dart';

// DEBUG ONLY — do not ship. Reached only via SplashPage's access-code
// prompt (see the class-level note on SplashPage's _accessCode) — by
// the time the user lands here, access has already been verified once,
// so this page does NOT re-prompt. It just shows the destination menu
// directly.
//
// To revert: change SplashPage's access-code success branch back to
// OnboardIntro and delete this file (and its import there).
class SplashNavigatingPage extends StatelessWidget {
  const SplashNavigatingPage({super.key});

  void _go(BuildContext context, Widget page) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  // Windows/desktop dev builds have no working IAP store, so
  // AppState().hasUnlockedApp is never set to true by a real purchase
  // — SafePrepNavBar's gate then bounces straight to OnboardPaywall
  // on any attempt to reach Dashboard or Rapid Fire. This forces the
  // unlocked state directly so local testing doesn't require a real
  // purchase or a TestFlight round-trip.
  //
  // kDebugMode-gated: compiles to nothing in release builds, so it
  // can never be used as a free-unlock path in a shipped app even if
  // this file is accidentally left wired in.
  void _forceUnlockForDebug() {
    if (!kDebugMode) return;
    AppState().hasUnlockedApp = true;
    AppState().purchaseType = PurchaseType.lifetime;
  }

  Widget _destButton(BuildContext context, String label, Widget page) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: AppSizes.primaryButtonHeight,
        child: ElevatedButton(
          onPressed: () => _go(context, page),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF13130F),
            foregroundColor: const Color(0xFFF0EDE8),
            side: const BorderSide(color: Color(0xFFD4AF37)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.buttonCornerRadius),
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Debug navigation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                _destButton(
                  context,
                  'FSME (post-purchase landing)',
                  const FsmePostPurchaseLanding(),
                ),
                _destButton(
                  context,
                  'Onboard Intro (funnel)',
                  const OnboardIntro(),
                ),
                _destButton(context, 'Home Page', const HomePage()),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    height: AppSizes.primaryButtonHeight,
                    child: ElevatedButton(
                      onPressed: () {
                        _forceUnlockForDebug();
                        _go(context, const DashboardPage());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13130F),
                        foregroundColor: const Color(0xFFF0EDE8),
                        side: const BorderSide(color: Color(0xFFD4AF37)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.buttonCornerRadius,
                          ),
                        ),
                      ),
                      child: const Text('Dashboard (force-unlocked)'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
