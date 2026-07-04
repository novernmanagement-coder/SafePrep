import 'dart:async';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'app_state.dart';
import 'trial_timer_service.dart';
import 'home_page.dart';
import 'dashboard_page.dart';
import 'rapid_fire_page.dart';

class SafePrepNavBar extends StatelessWidget {
  /// Set to true only from DashboardPage. When true and the user is still
  /// in trial mode, the "Dashboard" button is replaced with a live
  /// "Trial — mm:ss" countdown instead. Every other page keeps the normal
  /// "Dashboard" label regardless of this flag.
  final bool isDashboardPage;

  const SafePrepNavBar({super.key, this.isDashboardPage = false});

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

  @override
  Widget build(BuildContext context) {
    final bool showTimer = isDashboardPage && !AppState().hasUnlockedApp;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavButton(
            icon: Icons.home_outlined,
            label: 'Home',
            onTap: () => _goHome(context),
          ),
          showTimer
              ? _TrialTimerNavButton(onTap: () => _goDashboard(context))
              : _NavButton(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  onTap: () => _goDashboard(context),
                ),
          _NavButton(
            icon: Icons.bolt_outlined,
            label: 'Rapid Fire',
            onTap: () => _goRapidFire(context),
          ),
        ],
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
        width: AppSizes.footerButtonWidth,
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
        width: AppSizes.footerButtonWidth,
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
