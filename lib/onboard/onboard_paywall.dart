import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../mixpanel_service.dart';
import '../iap_service.dart';
import '../dashboard_page.dart';
import '../rapid_fire_limited_page.dart';
import '../rapid_fire_limited_intro.dart';
import 'onboard_answers.dart';
import 'onboard_diagnostic_questions.dart';
import 'onboard_post_purchase.dart';

/// Onboarding paywall — one screen, two modes.
///
/// [isRefresher] = false (default): the full $4.99 study plan, pitched
/// to users who scored < 8/10. Decline path shows trust anchors, the
/// money-back guarantee, a limited Rapid Fire option, and the Student
/// Presenter cross-sell at $29.99 (price anchoring — $4.99 looks cheap
/// next to it).
///
/// [isRefresher] = true: the $2.99 Refresher, pitched to users who
/// scored 8-10/10. They don't need a study plan, they need to stay
/// sharp. Decline path redirects to FSME Find a Proctor — they already
/// know the material, they need an exam seat.
///
/// Both paths set [has_completed_onboarding] so the funnel never replays.
class OnboardPaywall extends StatefulWidget {
  final bool isRefresher;

  /// When true, skip the main paywall and show the decline screen
  /// immediately. Used by the splash for returning users who already
  /// went through the funnel and declined — they get the purchase
  /// button + Rapid Fire + Student Presenter without redoing the
  /// diagnostic.
  final bool startOnDecline;

  const OnboardPaywall({
    super.key,
    this.isRefresher = false,
    this.startOnDecline = false,
  });

  @override
  State<OnboardPaywall> createState() => _OnboardPaywallState();
}

class _OnboardPaywallState extends State<OnboardPaywall> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _green = Color(0xFF639922);

  static const String _fsmeProctorUrl =
      'https://foodsafetymadeeasy.com/find-a-proctor/';
  static const String _fsmePresenterUrl =
      'https://foodsafetymadeeasy.com/servsafeonline/';

  late bool _showDecline = widget.startOnDecline;
  bool _purchasing = false;

  DiagnosticResult get _result =>
      OnboardingAnswers.instance.diagnosticResult ?? const DiagnosticResult([]);

  String get _price => widget.isRefresher ? '\$2.99' : '\$4.99';
  String get _duration => '7 days full access';

  String get _weakestCategory {
    final cats = _result.weakestCategories;
    return cats.isNotEmpty ? cats.first : 'your weakest area';
  }

  @override
  void initState() {
    super.initState();
    MixpanelService.instance.track(
      'onboarding_paywall_viewed',
      properties: {
        'app_name': 'SP',
        'mode': widget.isRefresher ? 'refresher' : 'full_plan',
        'readiness': _result.weightedScore,
      },
    );
  }

  /// Refresher app's App Store page. The $2.99 purchase happens in the
  /// Refresher app, not here — Apple only lets an app sell its own IAPs.
  /// Once the Refresher clears review this link goes live automatically.
  static const String _refresherAppStoreUrl =
      'https://apps.apple.com/app/safeprep-refresher/id6785239029';

  void _purchase() async {
    if (_purchasing) return;

    MixpanelService.instance.track(
      'onboarding_paywall_purchase',
      properties: {
        'app_name': 'SP',
        'mode': widget.isRefresher ? 'refresher' : 'full_plan',
        'price': _price,
      },
    );

    if (widget.isRefresher) {
      // Send them to the Refresher app on the App Store. The $2.99
      // IAP lives there, not in Manager. One codebase, one product.
      _launchUrl(_refresherAppStoreUrl);
    } else {
      setState(() => _purchasing = true);

      final result = await IAPService.instance.buySevenDay();

      if (!mounted) return;
      setState(() => _purchasing = false);

      if (result == IAPResult.success) {
        _goToPostPurchase();
      } else if (result == IAPResult.canceled) {
        // User backed out of the App Store sheet — do nothing, they're
        // still on the paywall and can try again or decline.
      } else {
        // Show error message for store unavailable, product not found,
        // timeout, or generic error.
        final message = result.userMessage;
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _goToPostPurchase() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnboardPostPurchase()),
      (_) => false,
    );
  }

  void _decline() {
    MixpanelService.instance.track(
      'onboarding_paywall_decline',
      properties: {
        'app_name': 'SP',
        'mode': widget.isRefresher ? 'refresher' : 'full_plan',
      },
    );

    if (widget.isRefresher) {
      // High scorers who decline get pointed to FSME to find a proctor.
      // They know the material — they need an exam seat. Stay on the
      // paywall so they can still purchase when they come back from
      // the browser.
      _launchUrl(_fsmeProctorUrl);
    } else {
      // Full-plan decliners get the trust anchor / decline screen.
      setState(() => _showDecline = true);
    }
  }

  void _declineRapidFire() {
    MixpanelService.instance.track(
      'onboarding_decline_rapid_fire',
      properties: {'app_name': 'SP'},
    );
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RapidFireLimitedIntro()),
      (_) => false,
    );
  }

  void _declinePresenter() {
    MixpanelService.instance.track(
      'onboarding_decline_presenter',
      properties: {'app_name': 'SP'},
    );
    _launchUrl(_fsmePresenterUrl);
  }

  void _goToDashboard() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DashboardPage()),
      (_) => false,
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Full plan paywall ───────────────────────────────────────────────

  Widget _fullPlanPaywall() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(flex: 2),

        Text(
          'YOUR PLAN IS READY',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
            color: _gold,
          ),
        ),

        const SizedBox(height: 14),

        Text(
          'Exam-ready in under 4 hours',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _softWhite,
            height: 1.3,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Without the 400 irrelevant questions other apps\n'
          'use to make you feel behind.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            color: _softWhite.withValues(alpha: 0.55),
            height: 1.5,
          ),
        ),

        const SizedBox(height: 24),

        _lockedRow(
          Icons.auto_awesome_outlined,
          'Your study plan has been created',
          'It adapts as you progress',
        ),
        _lockedRow(
          Icons.menu_book_outlined,
          'Category study guides',
          'Starting with ${_weakestCategory.toLowerCase()}',
        ),
        _lockedRow(Icons.bolt_outlined, 'Rapid Fire trainer', null),
        _lockedRow(Icons.timer_outlined, '60-Second Trainers', null),
        _lockedRow(Icons.quiz_outlined, 'Scenario drills', null),
        _lockedRow(
          Icons.assessment_outlined,
          'Full readiness assessment',
          null,
        ),

        const SizedBox(height: 24),

        _priceButton(),

        const SizedBox(height: 14),

        _rapidFireTaste(),

        const SizedBox(height: 10),

        _declineLink(),

        const Spacer(flex: 3),
      ],
    );
  }

  Widget _lockedRow(IconData icon, String title, String? sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _gold.withValues(alpha: 0.15), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _gold.withValues(alpha: 0.6)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _softWhite.withValues(alpha: 0.8),
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 11,
                        color: _gold.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.lock_outline,
              size: 14,
              color: _softWhite.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }

  // ── Refresher paywall ───────────────────────────────────────────────

  Widget _refresherPaywall() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(flex: 2),

        Text(
          'SUPERIOR QUIZ RESULTS',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
            color: _green,
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'You don\u2019t need a study plan.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _softWhite,
            height: 1.3,
          ),
        ),

        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'We recommend the Refresher version \u2014 five tools '
            'built to keep you in tune in 60-second spurts.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _softWhite.withValues(alpha: 0.6),
              height: 1.55,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Gold-ruled closing line
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: _gold.withValues(alpha: 0.3), width: 1),
              bottom: BorderSide(color: _gold.withValues(alpha: 0.3), width: 1),
            ),
          ),
          child: Text(
            'Use it right up until the proctor\nsays \u201Cphones off.\u201D',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: _gold,
              height: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 28),

        _priceButton(),

        const SizedBox(height: 14),

        _declineLink(),

        const Spacer(flex: 3),
      ],
    );
  }

  // ── Decline screen ($4.99 only) ─────────────────────────────────────

  Widget _declineScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(flex: 2),

        Text(
          'BEFORE YOU GO',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
            color: _gold,
          ),
        ),

        const SizedBox(height: 14),

        Text(
          'We\u2019re not a test-prep company.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _softWhite,
            height: 1.3,
          ),
        ),

        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'We\u2019re certified ServSafe instructors and registered '
            'proctors who built the tool we wished existed. '
            '20+ years of classroom experience, distilled into '
            'what actually gets tested.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: _softWhite.withValues(alpha: 0.55),
              height: 1.6,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Money-back guarantee — the load-bearing element.
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _gold.withValues(alpha: 0.3), width: 1),
          ),
          child: Column(
            children: [
              Icon(Icons.verified_outlined, size: 28, color: _gold),
              const SizedBox(height: 8),
              Text(
                'Pass, or your money back.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _softWhite,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'The risk is ours, not yours.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: _softWhite.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Re-ask: $4.99 unlock button
        _priceButton(),

        const SizedBox(height: 20),

        // Option 1: Limited Rapid Fire
        _exitOption(
          icon: Icons.bolt_outlined,
          text:
              'Not ready to commit? Try our 60-second '
              'Rapid Fire tool for free.',
          onTap: _declineRapidFire,
        ),

        const SizedBox(height: 10),

        // Option 2: Student Presenter cross-sell with $29.99 anchor
        _exitOption(
          icon: Icons.school_outlined,
          text:
              'Would you prefer a classroom-style tutorial? We offer '
              'the Student Presenter online course \u2014 \$29.99',
          onTap: _declinePresenter,
        ),

        const Spacer(flex: 3),
      ],
    );
  }

  Widget _exitOption({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _gold.withValues(alpha: 0.15), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _gold.withValues(alpha: 0.5)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: _softWhite.withValues(alpha: 0.55),
                  height: 1.5,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: _softWhite.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared widgets ──────────────────────────────────────────────────

  Widget _priceButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _purchasing ? null : _purchase,
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: _darkBg,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonCornerRadius),
          ),
        ),
        child: _purchasing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _darkBg,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Unlock SafePrep  \u2014  $_price',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _duration,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w400,
                      color: _darkBg.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Rapid Fire taste — positioned near the decline link so someone
  /// about to bail has a third door. Only on the full plan paywall.
  Widget _rapidFireTaste() {
    return GestureDetector(
      onTap: () {
        MixpanelService.instance.track(
          'onboarding_paywall_rapid_fire_taste',
          properties: {'app_name': 'SP'},
        );
        // TODO: open inline Rapid Fire demo drawn from their weakest
        // categories. Track tap rate vs conversion after.
      },
      child: Text(
        'Try the Rapid Fire tool for 60 seconds',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _gold,
        ),
      ),
    );
  }

  Widget _declineLink() {
    return GestureDetector(
      onTap: _decline,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          widget.isRefresher ? 'Find a proctor in my area' : 'Not right now',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: _softWhite.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
          child: _showDecline
              ? _declineScreen()
              : widget.isRefresher
              ? _refresherPaywall()
              : _fullPlanPaywall(),
        ),
      ),
    );
  }
}
