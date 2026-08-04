import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'constants.dart';
import 'mixpanel_service.dart';
import 'cluster_info_page.dart';
import 'home_page.dart';

/// The one-time post-purchase FSME landing page. Full FSME voice —
/// buddy, ally, overconfident — as opposed to the clinical tone of
/// [ClusterInfoPage], which this page opens for each cluster.
///
/// User-paced reveal: FSME types an intro line, then a thin "Continue"
/// control appears below the speech box. Tapping it types the next
/// cluster's line, fades its button in below (locked/non-interactive
/// while the tour is still playing), then shows the thin Continue
/// again. Repeats through all five clusters — nothing auto-advances on
/// a timer, so someone can read at their own pace or tap straight
/// through. After the last cluster, a wrap-up line plays, the five
/// buttons unlock, and a full-width Continue button appears that drops
/// the user straight into the app on the Home Page. Tapping a cluster
/// button (once unlocked) opens [ClusterInfoPage] for that cluster
/// with [ClusterLaunchContext.landing].
class FsmePostPurchaseLanding extends StatefulWidget {
  const FsmePostPurchaseLanding({super.key});

  @override
  State<FsmePostPurchaseLanding> createState() =>
      _FsmePostPurchaseLandingState();
}

class _ClusterStop {
  final AppCluster cluster;
  final String label;
  final IconData icon;
  final String line;
  const _ClusterStop({
    required this.cluster,
    required this.label,
    required this.icon,
    required this.line,
  });
}

class _FsmePostPurchaseLandingState extends State<FsmePostPurchaseLanding>
    with TickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _eyeRed = Color(0xFFE24B4A);

  static const Duration _typeCharDelay = Duration(milliseconds: 18);
  static const Duration _fadeGap = Duration(milliseconds: 320);
  static const Duration _buttonRevealGap = Duration(milliseconds: 400);

  static const String _introLine =
      "Alright my friend, before you get started let me 'splain how "
      "this app works. First off \u2014 you do you. Want to study first? "
      "Great. Want to hit one of my 60-second trainers right out the "
      "gate? Excellent. Want to narrow your study curriculum? Take "
      "the assessment.";

  static const String _wrapUpLine =
      "If you want a complete breakdown of each cluster, just select "
      "it. Otherwise, select Continue and you'll be inside the app "
      "on the Home Page.";

  static const List<_ClusterStop> _stops = [
    _ClusterStop(
      cluster: AppCluster.assessment,
      label: 'The Assessment',
      icon: Icons.fact_check_outlined,
      line:
          "There are basically 5 things you can do around here. "
          "Let's start with the Assessment cluster \u2014 this is where "
          "you get a personalized plan. When I first got here, I "
          "took the assessment. But hey \u2014 you do you.",
    ),
    _ClusterStop(
      cluster: AppCluster.dashboardStudy,
      label: 'Dashboard and Study',
      icon: Icons.dashboard_customize_outlined,
      line:
          "Next \u2014 the Dashboard. This is the beast that does the "
          "heavy lifting. Every category, your scores, what's "
          "mastered, what still needs work \u2014 it all lives here.",
    ),
    _ClusterStop(
      cluster: AppCluster.trainers,
      label: 'The Trainers',
      icon: Icons.bolt_outlined,
      line:
          "Trainers: Dude, I'm telling you \u2014 and not just because I "
          "made these \u2014 this is the best part of the app. You can "
          "reinforce information, you can actually learn everything "
          "you need to without even realizing it. Best of all, "
          "anytime, day or night, you pop in and within 60 seconds "
          "or less you just got your brain back in ServSafe test "
          "mode.",
    ),
    _ClusterStop(
      cluster: AppCluster.settings,
      label: 'Settings',
      icon: Icons.settings_outlined,
      line:
          "All apps have this \u2014 this is where the boring legal "
          "stuff lives, the resets can get reset... but usefully, "
          "you can review what all these clusters can do for you, "
          "anytime.",
    ),
    _ClusterStop(
      cluster: AppCluster.finalExam,
      label: 'The Final Exam',
      icon: Icons.workspace_premium_outlined,
      line:
          "The Final Exam: your Ahab \u2014 this is the whale. 90 "
          "questions, scored exactly like the real ServSafe exam. "
          "And here's the best part: whatever your results, I use "
          "them to hone your curriculum.",
    ),
  ];

  String _displayedText = '';
  final List<_ClusterStop> _revealedStops = [];
  bool _unlocked = false;
  bool _finished = false;

  // True whenever the thin "Continue" control should be visible — i.e.
  // a line has finished typing (and, for stops, its button has faded
  // in) and we're waiting on the user to tap through to the next one.
  // Replaces the old timer-driven auto-advance entirely.
  bool _showContinue = false;

  Timer? _typeTimer;

  // Gaze + blink machinery, matching the established FSME eye pattern
  // used elsewhere in the funnel (OnboardIntro, OnboardExamDate).
  int _gazeTarget = 0;
  double _gazeCurrent = 0.0;
  Timer? _gazeTimer;
  late AnimationController _gazeAnim;
  late AnimationController _blinkController;
  Timer? _blinkTimer;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();

    MixpanelService.instance.track(
      'post_purchase_landing_viewed',
      properties: {'app_name': 'SP'},
    );

    _gazeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(_advanceGaze);
    _gazeAnim.repeat();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _scheduleGaze();
    _scheduleBlink();

    _playIntro();
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _gazeTimer?.cancel();
    _blinkTimer?.cancel();
    _gazeAnim.dispose();
    _blinkController.dispose();
    super.dispose();
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
      if (!mounted) return;
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
      if (!mounted) return;
      await _blinkController.forward(from: 0.0);
      if (mounted) await _blinkController.reverse();
      _scheduleBlink();
    });
  }

  Future<void> _typeLine(String text, {VoidCallback? onDone}) async {
    setState(() => _displayedText = '');
    for (var i = 1; i <= text.length; i++) {
      if (!mounted) return;
      await Future.delayed(_typeCharDelay);
      if (!mounted) return;
      setState(() => _displayedText = text.substring(0, i));
    }
    onDone?.call();
  }

  Future<void> _fadeToLine(String text, {VoidCallback? onDone}) async {
    setState(() => _displayedText = '');
    await Future.delayed(_fadeGap);
    if (!mounted) return;
    await _typeLine(text, onDone: onDone);
  }

  Future<void> _playIntro() async {
    await _typeLine(_introLine);
    if (!mounted) return;
    setState(() => _showContinue = true);
  }

  /// Fires on every tap of the thin Continue control. Advances exactly
  /// one step: either reveals the next cluster's line + button, or —
  /// once all five are shown — plays the wrap-up line and unlocks the
  /// tour. Nothing here runs on its own; it only moves forward when
  /// the user taps.
  Future<void> _advance() async {
    setState(() => _showContinue = false);

    if (_revealedStops.length < _stops.length) {
      final stop = _stops[_revealedStops.length];
      await _fadeToLine(stop.line);
      if (!mounted) return;
      await Future.delayed(_buttonRevealGap);
      if (!mounted) return;
      setState(() {
        _revealedStops.add(stop);
        _showContinue = true;
      });
    } else {
      await _fadeToLine(
        _wrapUpLine,
        onDone: () {
          if (!mounted) return;
          setState(() {
            _unlocked = true;
            _finished = true;
          });
        },
      );
    }
  }

  void _openCluster(AppCluster cluster) {
    if (!_unlocked) return;
    MixpanelService.instance.track(
      'post_purchase_cluster_opened',
      properties: {
        'cluster': cluster.name,
        'source': 'post_purchase_landing',
        'app_name': 'SP',
      },
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClusterInfoPage(
          cluster: cluster,
          launchContext: ClusterLaunchContext.landing,
        ),
      ),
    );
  }

  void _continue() {
    MixpanelService.instance.track(
      'post_purchase_landing_continue',
      properties: {'app_name': 'SP'},
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  void _skipTour() {
    MixpanelService.instance.track(
      'post_purchase_landing_skipped',
      properties: {'stops_seen': _revealedStops.length, 'app_name': 'SP'},
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [_davEye(), const SizedBox(width: 10), _davEye()],
              ),
              const SizedBox(height: 8),
              Text(
                'F S M E',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  color: _gold.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  minHeight: 70,
                  maxHeight: 150,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _gold.withValues(alpha: 0.25)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _displayedText,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: _gold,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
              if (_showContinue && !_finished) _thinContinue(),
              const SizedBox(height: 16),
              Column(
                spacing: 8,
                children: [
                  for (final stop in _revealedStops) _clusterButton(stop),
                ],
              ),
              if (_finished) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.primaryButtonHeight,
                  child: ElevatedButton(
                    onPressed: _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _darkBg,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.buttonCornerRadius,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Continue  \u2192',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              _skipTourSection(),
            ],
          ),
        ),
      ),
    );
  }

  /// Small, understated tap target shown under the speech box between
  /// beats — deliberately not styled like a primary button. It's a
  /// pacing control, not a decision point, so it should read as "tap
  /// when ready" rather than compete visually with the cluster buttons
  /// or the final gold Continue CTA.
  Widget _thinContinue() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _advance,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: _gold.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: _gold.withValues(alpha: 0.75),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Sits at the very bottom of the scrolling content, below whatever
  /// cluster buttons have revealed so far — as more stops appear this
  /// section gets pushed further down, but it's always the last thing
  /// in the column. Lets someone bail out at any point in the tour
  /// (not just after it finishes) without losing anything permanently,
  /// since the same explanations are reachable again later from
  /// Settings via ClusterInfoPage.
  Widget _skipTourSection() {
    return Column(
      children: [
        Text(
          'You can always come back to these explanations later from '
          'Settings.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: _softWhite.withValues(alpha: 0.45),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _skipTour,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                'Skip \u2014 take me to Home',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: _softWhite.withValues(alpha: 0.55),
                  decoration: TextDecoration.underline,
                  decorationColor: _softWhite.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _clusterButton(_ClusterStop stop) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _unlocked ? () => _openCluster(stop.cluster) : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _gold.withValues(alpha: _unlocked ? 0.6 : 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(stop.icon, size: 16, color: _gold),
                    const SizedBox(width: 8),
                    Text(
                      stop.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: _softWhite,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: _gold.withValues(alpha: _unlocked ? 0.9 : 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _davEye() {
    return AnimatedBuilder(
      animation: Listenable.merge([_gazeAnim, _blinkController]),
      builder: (context, _) {
        final blink = 1.0 - _blinkController.value * 0.92;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(1.0, blink),
          child: Container(
            width: 34,
            height: 34,
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
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Transform.translate(
                offset: Offset(_gazeCurrent * 6, 0.5),
                child: Container(
                  width: 9,
                  height: 11,
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
}
