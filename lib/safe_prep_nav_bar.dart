import 'dart:async';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'app_state.dart';
import 'trial_timer_service.dart';
import 'mixpanel_service.dart';
import 'iap_service.dart';
import 'home_page.dart';
import 'dashboard_page.dart';
import 'rapid_fire_page.dart';

class SafePrepNavBar extends StatefulWidget {
  /// Set to true only from DashboardPage. When true and the user is still
  /// in trial mode, the "Dashboard" button is replaced with a live
  /// "Trial — mm:ss" countdown instead. Every other page keeps the normal
  /// "Dashboard" label regardless of this flag.
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

  void _goDashboard(BuildContext context) {
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

  // Nav bar's Unlock button buys the $4.99 / 7-day product directly —
  // no PreviewRevealPage detour. Someone tapping "Unlock" from the nav
  // bar has already shown intent; making them choose between three
  // prices on a separate page is an extra step they didn't ask for.
  // The 3-price selector on PreviewRevealPage (reached via trial
  // expiration or the Home page banner) is untouched.
  //
  // _buyNow now waits for IAPService to resolve the actual outcome
  // (success / canceled / error / timeout) instead of just "request
  // submitted" — the loading spinner stays up for the whole App Store
  // sheet interaction, and the person gets real feedback either way
  // instead of the button silently resetting with nothing having
  // visibly happened.
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
      return; // isUnlocked flips on next build — Unlock button disappears
    }

    if (result == IAPResult.canceled) {
      // User intentionally backed out of the App Store sheet — no error,
      // nothing to show. This IS the fix for "nothing happens": before,
      // the button reset silently too, but now it's a deliberate no-op
      // instead of an accidental one — we know for certain they canceled
      // rather than guessing from a swallowed stream event.
      return;
    }

    final message = result.userMessage;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isUnlocked = AppState().hasUnlockedApp;
    final bool showTimer = widget.isDashboardPage && !isUnlocked;

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
            child: showTimer
                ? _TrialTimerNavButton(onTap: () => _goDashboard(context))
                : _NavButton(
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
          // Persistent purchase CTA — shown on every page that includes
          // this nav bar, for as long as the user hasn't unlocked. This
          // is intentionally the ONLY nav item styled to stand out (gold),
          // since it's the primary conversion path and previously was only
          // reachable via a banner buried well down the Home page scroll.
          if (!isUnlocked)
            Expanded(
              child: _UnlockNavButton(
                loading: _purchaseInFlight,
                onTap: () => _buyNow(context),
              ),
            ),
        ],
      ),
    );
  }
}

/// Persistent gold "Unlock" nav button. Only rendered for trial users, on
/// every page that includes SafePrepNavBar — gives the purchase flow a
/// fixed, always-visible entry point instead of relying on users to find
/// a banner further down an individual page.
class _UnlockNavButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _UnlockNavButton({required this.onTap, this.loading = false});

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
                'Unlock',
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

/// Dashboard-only nav slot that displays a live-ticking "Trial — mm:ss"
/// countdown in place of the normal Dashboard label/icon, reading from the
/// same TrialTimerService instance used elsewhere so it never drifts out
/// of sync with the actual expiration logic.
class _TrialTimerNavButton extends StatefulWidget {
  final VoidCallback onTap;

  const _TrialTimerNavButton({required this.onTap});

  @override
  State<_TrialTimerNavButton> createState() => _TrialTimerNavButtonState();
}

class _TrialTimerNavButtonState extends State<_TrialTimerNavButton> {
  Timer? _displayTicker;

  @override
  void initState() {
    super.initState();
    _displayTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _displayTicker?.cancel();
    super.dispose();
  }

  String get _formatted {
    final remaining = TrialTimerService.instance.remainingSeconds;
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
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
              Icon(
                Icons.timer_outlined,
                size: 18,
                color: AppColors.secondaryButtonForeground,
              ),
              Text(
                'Trial — $_formatted',
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
