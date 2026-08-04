import 'package:flutter/material.dart';
import 'constants.dart';
import 'app_state.dart';
import 'mixpanel_service.dart';
import 'iap_service.dart';
import 'home_page.dart';
import 'dashboard_page.dart';
import 'rapid_fire_page.dart';
import 'preview/preview_reveal_page.dart';

class SafePrepNavBar extends StatefulWidget {
  final bool isDashboardPage;

  const SafePrepNavBar({super.key, this.isDashboardPage = false});

  @override
  State<SafePrepNavBar> createState() => _SafePrepNavBarState();
}

class _SafePrepNavBarState extends State<SafePrepNavBar> {
  bool _purchaseInFlight = false;

  void _goHome(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  // Gated on real purchase state — either never purchased, or a
  // sevenDay/fourteenDay purchase whose calendar expiry has passed
  // (AppState.isExpired, purchaseDate + duration vs. now). This
  // replaces the old TrialTimerService-based check, which stopped
  // meaning anything once the trial system was removed. This is the
  // same gate that was added after the paywall-bypass bug found here
  // previously (Dashboard nav had zero purchase check) — kept
  // deliberately strict rather than just deleted, so that bug can't
  // quietly reopen for an expired purchaser.
  void _goDashboard(BuildContext context) {
    final state = AppState();
    final bool locked = !state.hasUnlockedApp || state.isExpired;
    if (locked) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => PreviewRevealPage()),
        (route) => false,
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardPage()),
    );
  }

  void _goRapidFire(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RapidFirePage()),
    );
  }

  // NOTE: still calls buySevenDay() — the ORIGINAL first-purchase
  // product. This is a placeholder, not a real renewal. Apple
  // non-consumables (which kProductSevenDay is) can only be bought
  // ONCE per Apple ID ever — tapping this a second time doesn't
  // charge again or extend anything, StoreKit just silently treats
  // it as "already owned." A real renewal needs the $2.99 repeatable
  // CONSUMABLE product (kProductRenewalWeek / buyRenewal()) already
  // drafted in iap_service.dart but not yet created in App Store
  // Connect or shipped — see the flag at the bottom of this file.
  Future<void> _buyNow(BuildContext context) async {
    if (_purchaseInFlight) return;
    setState(() => _purchaseInFlight = true);

    MixpanelService.instance.track(
      'paywall_viewed',
      properties: {'source': 'nav_bar', 'app_name': 'SP'},
    );

    final result = await IAPService.instance.buySevenDay();

    if (!mounted) return;
    setState(() => _purchaseInFlight = false);

    if (result == IAPResult.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("You're unlocked! 🎉")));
      return;
    }

    if (result == IAPResult.canceled) {
      return;
    }

    final message = result.userMessage;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("You're unlocked! 🎉")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState();

    // Temporarily disabled for this submission via an impossible
    // threshold — plans max out at 14 days remaining, so requiring
    // 50+ can never be true. Renew's tap action isn't wired to a real
    // purchase yet (still calls buySevenDay(), a non-consumable),
    // so this keeps the button hidden until that's built. Lower the
    // 50 back down (e.g. to 2) once the real renewal IAP is ready.
    final bool showRenew =
        state.isTimeLimited && (state.daysRemaining ?? 0) >= 50;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        spacing: 6,
        children: [
          Expanded(
            child: _NavButton(
              icon: Icons.home_outlined,
              label: 'Home',
              onTap: () => _goHome(context),
            ),
          ),
          Expanded(
            child: _NavButton(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              onTap: () => _goDashboard(context),
            ),
          ),
          Expanded(
            child: _NavButton(
              icon: Icons.bolt_outlined,
              label: 'Rapid Fire',
              onTap: () => _goRapidFire(context),
            ),
          ),
          if (showRenew)
            Expanded(
              child: _RenewNavButton(
                loading: _purchaseInFlight,
                onTap: () => _buyNow(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _RenewNavButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _RenewNavButton({required this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: SizedBox(
        height: AppSizes.footerButtonHeight,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0F),
            border: Border.all(
              color: const Color(0xFFD4AF37),
              width: AppSizes.buttonBorderThickness,
            ),
            borderRadius: BorderRadius.circular(
              AppSizes.footerButtonCornerRadius,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 2,
            children: [
              loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFD4AF37),
                      ),
                    )
                  : const Icon(Icons.star, size: 18, color: Color(0xFFD4AF37)),
              Text(
                'Renew',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppFonts.label,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD4AF37),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: AppSizes.footerButtonHeight,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.secondaryButton,
            border: Border.all(
              color: AppColors.footerButtonBorder,
              width: AppSizes.buttonBorderThickness,
            ),
            borderRadius: BorderRadius.circular(
              AppSizes.footerButtonCornerRadius,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 2,
            children: [
              Icon(icon, size: 18, color: AppColors.secondaryButtonForeground),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppFonts.label,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondaryButtonForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// STILL OPEN — the Renew button's TAP ACTION is a placeholder.
// Gating/label are correct now (shows for existing sevenDay/
// fourteenDay purchasers within 2 days of expiry or already
// expired), but _buyNow() still calls buySevenDay() — the original
// non-consumable product, which Apple only allows ONE purchase of
// per Apple ID ever. Tapping "Renew" right now would NOT charge
// again or add days; it would just resolve as "already owned."
// Making Renew actually work requires the $2.99 repeatable
// CONSUMABLE IAP (kProductRenewalWeek / buyRenewal()) already
// drafted in iap_service.dart — that product still needs to be
// created in App Store Connect and _buyNow() switched to call
// buyRenewal() instead of buySevenDay(). This was paused earlier
// because tying a new IAP to a build had been a headache before —
// worth confirming whether that's still the case before wiring it
// in for real.
// ─────────────────────────────────────────────────────────────────
