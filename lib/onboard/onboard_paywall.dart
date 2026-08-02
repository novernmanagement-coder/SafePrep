import 'dart:math' as math;
import 'dart:async';
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

/// Who an FSME line is directed at / how it renders. Matches the system
/// used across the rest of the onboarding funnel.
/// - user: FSME's default voice (gold)
/// - boss: directed at the boss (blue)
/// - self: muttering/thinking to himself (gray)
/// - processing: system-status bits — teal
enum _FsmeAudience { user, boss, self, processing }

class _FsmeLine {
  final String text;
  final _FsmeAudience audience;
  const _FsmeLine(this.text, {this.audience = _FsmeAudience.user});
}

class _OnboardPaywallState extends State<OnboardPaywall>
    with TickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _green = Color(0xFF639922);
  // Matches the boss-line / self-line / processing colors used across
  // the rest of the funnel.
  static const Color _bossBlue = Color(0xFF4A9BE2);
  static const Color _selfGray = Color(0xFF9E9E9E);
  static const Color _processingTeal = Color(0xFF6FA8A6);

  static const String _fsmeProctorUrl =
      'https://foodsafetymadeeasy.com/find-a-proctor/';
  static const String _fsmePresenterUrl =
      'https://foodsafetymadeeasy.com/servsafeonline/';

  late bool _showDecline = widget.startOnDecline;
  bool _purchasing = false;

  // FSME testimonial pop-up (full-plan paywall only): fades in 2s after
  // the screen appears, types one line, then leaves 1s after finishing.
  static const Color _eyeRed = Color(0xFFE24B4A);
  bool _fsmeVisible = false;
  String _fsmeTyped = '';
  Timer? _fsmeInTimer;
  Timer? _fsmeTypeTimer;
  Timer? _fsmeOutTimer;
  int _gazeTarget = 0;
  double _gazeCurrent = 0.0;
  Timer? _gazeTimer;
  AnimationController? _gazeAnim;
  AnimationController? _blinkController;
  Timer? _blinkTimer;
  final math.Random _rng = math.Random();
  static const String _fsmeLine =
      "Dude, I didn't know a thing about food safety. Then I "
      'came to work here. Man — this system works.';

  // ── Decline-screen FSME box ──────────────────────────────────────────
  // "Undo BFF script" only makes sense if the user actually saw the BFF-
  // digits bit, which only fires on the "Answers and explanations" study
  // style. Gated below rather than shown unconditionally.
  static const List<_FsmeLine> _declineFsmeScriptWithBffCallback = [
    _FsmeLine('Undo BFF script...', audience: _FsmeAudience.processing),
    _FsmeLine(
      'Change digits: XXXX XXXX XXXX',
      audience: _FsmeAudience.processing,
    ),
    _FsmeLine('Dude, really? Was it because I ordered a large combo?'),
    _FsmeLine(
      "Seriously \u2014 there's zero risk. If we're not what we say we "
      'are,',
    ),
    _FsmeLine(
      'we\u2019ll give you your money back. Give it a shot \u2014 this is '
      'what we do:',
    ),
    _FsmeLine('get people ready for the exam.'),
  ];

  /// Fallback for study styles that never saw the BFF-digits bit — skips
  /// straight to the reassurance without the callback that wouldn't
  /// land for them.
  static const List<_FsmeLine> _declineFsmeScriptPlain = [
    _FsmeLine("Hey \u2014 before you go."),
    _FsmeLine(
      "Seriously \u2014 there's zero risk. If we're not what we say we "
      'are,',
    ),
    _FsmeLine(
      'we\u2019ll give you your money back. Give it a shot \u2014 this is '
      'what we do:',
    ),
    _FsmeLine('get people ready for the exam.'),
  ];

  bool _declineFsmeVisible = false;
  final List<_FsmeLine> _declineFsmeLines = [];
  Timer? _declineFsmeInTimer;
  bool _declineFsmeStarted = false;

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
      'SpOn_Pay_Viewed',
      properties: {
        'app_name': 'SP',
        'tier': widget.isRefresher ? 'refresher' : 'sp',
        'readiness': _result.readinessScore,
      },
    );

    // Eye animation is needed for the full-plan testimonial AND the
    // decline-screen FSME box — both live outside the refresher tier.
    if (!widget.isRefresher) {
      _gazeAnim = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      )..addListener(_advanceGaze);
      _gazeAnim!.repeat();
      _blinkController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 180),
      );
    }

    if (!widget.startOnDecline && !widget.isRefresher) {
      _fsmeInTimer = Timer(const Duration(seconds: 2), _startFsme);
    }

    if (widget.startOnDecline && !widget.isRefresher) {
      _declineFsmeInTimer = Timer(
        const Duration(seconds: 2),
        _startDeclineFsme,
      );
    }
  }

  void _advanceGaze() {
    final target = _gazeTarget.toDouble();
    final next = _gazeCurrent + (target - _gazeCurrent) * 0.18;
    if ((next - _gazeCurrent).abs() > 0.001) {
      setState(() => _gazeCurrent = next);
    }
  }

  void _scheduleGaze() {
    final delay = Duration(milliseconds: 1800 + _rng.nextInt(2200));
    _gazeTimer = Timer(delay, () {
      if (!mounted || !_fsmeVisible) return;
      if (_rng.nextDouble() < 0.30) {
        setState(() => _gazeTarget = _rng.nextBool() ? -1 : 1);
        Timer(Duration(milliseconds: 700 + _rng.nextInt(400)), () {
          if (mounted) setState(() => _gazeTarget = 0);
        });
      } else {
        setState(() => _gazeTarget = 0);
      }
      _scheduleGaze();
    });
  }

  void _scheduleBlink() {
    final delay = Duration(milliseconds: 3000 + _rng.nextInt(5000));
    _blinkTimer = Timer(delay, () async {
      if (!mounted || !_fsmeVisible) return;
      await _blinkController?.forward(from: 0.0);
      if (mounted) await _blinkController?.reverse();
      _scheduleBlink();
    });
  }

  /// Fade in, type the line char-by-char, then leave 1s after the last
  /// character lands.
  void _startFsme() {
    if (!mounted) return;
    setState(() => _fsmeVisible = true);
    _scheduleGaze();
    _scheduleBlink();
    int i = 0;
    _fsmeTypeTimer = Timer.periodic(const Duration(milliseconds: 32), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      i++;
      setState(
        () => _fsmeTyped = _fsmeLine.substring(0, i.clamp(0, _fsmeLine.length)),
      );
      if (i >= _fsmeLine.length) {
        timer.cancel();
        _fsmeOutTimer = Timer(const Duration(seconds: 4), () {
          if (!mounted) return;
          // Fade out first...
          setState(() => _fsmeVisible = false);
          // ...then collapse the height (clear text) so the button slides
          // back up under the readiness box, after the fade completes.
          Timer(const Duration(milliseconds: 320), () {
            if (mounted) setState(() => _fsmeTyped = '');
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _fsmeInTimer?.cancel();
    _fsmeTypeTimer?.cancel();
    _fsmeOutTimer?.cancel();
    _declineFsmeInTimer?.cancel();
    _gazeTimer?.cancel();
    _blinkTimer?.cancel();
    _gazeAnim?.dispose();
    _blinkController?.dispose();
    super.dispose();
  }

  /// Refresher app's App Store page. The $2.99 purchase happens in the
  /// Refresher app, not here — Apple only lets an app sell its own IAPs.
  /// Once the Refresher clears review this link goes live automatically.
  static const String _refresherAppStoreUrl =
      'https://apps.apple.com/app/safeprep-refresher/id6785238865';
  void _purchase() async {
    if (_purchasing) return;

    MixpanelService.instance.track(
      'SpOn_Purchase',
      properties: {
        'app_name': 'SP',
        'tier': widget.isRefresher ? 'refresher' : 'sp',
        'source': 'paywall',
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
      'SpOn_Pay_Decline',
      properties: {
        'app_name': 'SP',
        'tier': widget.isRefresher ? 'refresher' : 'sp',
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
      _declineFsmeInTimer ??= Timer(
        const Duration(seconds: 2),
        _startDeclineFsme,
      );
    }
  }

  void _declineRapidFire() {
    MixpanelService.instance.track(
      'SpOn_Pay_DeclineToRapidFire',
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
      'SpOn_Pay_DeclineToPresenter',
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
        const SizedBox(height: 30),

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

        _fsmeTestimonial(),

        _priceButton(),

        const SizedBox(height: 14),

        _rapidFireTaste(),

        const SizedBox(height: 10),

        _declineLink(),

        const SizedBox(height: 40),
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
        const SizedBox(height: 30),

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

        const SizedBox(height: 40),
      ],
    );
  }

  // ── Decline screen ($4.99 only) ─────────────────────────────────────

  Widget _declineScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 30),

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

        _declineFsmeBox(),

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

        const SizedBox(height: 40),
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

  /// FSME testimonial pop-up — reserves fixed vertical space so the
  /// unlock button never reflows as he appears/leaves. Fades in, types
  /// his line, fades out.
  Widget _fsmeTestimonial() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: _fsmeVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 2300),
        // Height collapses to 0 when he's gone, so the unlock button
        // slides back up under the readiness box; expands when he appears.
        child: _fsmeVisible || _fsmeTyped.isNotEmpty
            ? Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _davEye(),
                    ),
                    const SizedBox(width: 6),
                    _davEye(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _fsmeTyped,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                          color: _softWhite.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox(width: double.infinity, height: 0),
      ),
    );
  }

  /// Starts the decline-screen FSME box: appears ~2s after landing on
  /// decline, then the (study-style-gated) script types in one line at
  /// a time.
  Future<void> _startDeclineFsme() async {
    if (!mounted || _declineFsmeStarted) return;
    _declineFsmeStarted = true;

    setState(() => _declineFsmeVisible = true);
    _scheduleGaze();
    _scheduleBlink();

    final sawBffBit =
        OnboardingAnswers.instance.studyStyle == StudyStyle.explanations;
    final script = sawBffBit
        ? _declineFsmeScriptWithBffCallback
        : _declineFsmeScriptPlain;

    for (final line in script) {
      if (!mounted) return;
      setState(() => _declineFsmeLines.add(line));
      await Future.delayed(const Duration(milliseconds: 750));
    }
  }

  Widget _davEye() {
    final gaze = _gazeAnim;
    final blinkC = _blinkController;
    if (gaze == null || blinkC == null)
      return const SizedBox(width: 24, height: 24);
    return AnimatedBuilder(
      animation: Listenable.merge([gaze, blinkC]),
      builder: (context, _) {
        final blink = 1.0 - blinkC.value * 0.92;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(1.0, blink),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFFFF2200),
                  Color(0xFFCC1100),
                  Color(0xFF660000),
                  Color(0xFF1A0000),
                ],
                stops: [0.0, 0.35, 0.7, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: _eyeRed.withValues(alpha: 0.6),
                  blurRadius: 9,
                  spreadRadius: 1.5,
                ),
              ],
            ),
            child: Center(
              child: Transform.translate(
                offset: Offset(_gazeCurrent * 4, 0.5),
                child: Container(
                  width: 7,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0000),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Decline-screen FSME box — a mock-hurt reaction to being declined
  /// (the "Undo BFF script" callback, when applicable) that pivots into
  /// a plain-spoken restate of the money-back guarantee.
  Widget _declineFsmeBox() {
    return AnimatedOpacity(
      opacity: _declineFsmeVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 2300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _davEye(),
              const SizedBox(width: 10),
              Text(
                'F S M E',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 3,
                  color: _eyeRed.withValues(alpha: 0.3),
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(width: 10),
              _davEye(),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _gold.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final line in _declineFsmeLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '> ${line.text}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.5,
                        color: switch (line.audience) {
                          _FsmeAudience.boss => _bossBlue,
                          _FsmeAudience.self => _selfGray,
                          _FsmeAudience.processing => _processingTeal,
                          _FsmeAudience.user => _gold.withValues(alpha: 0.8),
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
  ///
  /// Uses a returnable push (not pushAndRemoveUntil): the taste is a
  /// hook, not an exit. When they back out of or finish the limited
  /// Rapid Fire, they land back on the paywall, still able to buy.
  Widget _rapidFireTaste() {
    return GestureDetector(
      onTap: () {
        MixpanelService.instance.track(
          'SpOn_Pay_RapidFireTaste',
          properties: {'app_name': 'SP'},
        );
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RapidFireLimitedIntro()),
        );
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
        child: SingleChildScrollView(
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
