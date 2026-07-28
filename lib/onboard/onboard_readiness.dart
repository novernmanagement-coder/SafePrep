import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../mixpanel_service.dart';
import 'onboard_answers.dart';
import 'onboard_diagnostic_questions.dart';
import 'onboard_paywall.dart';

/// Results, beat 2 of 2 — the readiness verdict, delivered by FSME.
///
/// The category screen built the case; this screen delivers it. A score
/// ring on top ([DiagnosticResult.readinessScore] + band tag), then an
/// FSME terminal readout that reads out the two raw signals and gives a
/// per-cell assessment + recommendation.
///
/// ── The 3×3 read ──────────────────────────────────────────────────────
/// FSME's assessment keys off two axes, each in three bands:
///
///   Confidence (avg stars):  Low <3 · Mid 3–4 · High >4
///   Knowledge  (correct):    Low ≤5 · Mid 6–7 · High 8–10
///
/// Nine cells, each with its own assessment line and recommendation. The
/// score ring still shows readinessScore (correctness × confidence-
/// calibration penalty); the FSME box explains what that score means and
/// what to do about it — so a high scorer who hedged understands why
/// they're pointed at the full plan rather than the Refresher.
///
/// ── Refresher gate ────────────────────────────────────────────────────
/// Only the High/High cell (correct ≥8 AND avg stars >4) recommends the
/// $2.99 Refresher — very good knowledge AND the confidence to sit the
/// exam today. Every other cell routes to the full $4.99 plan.
class OnboardReadiness extends StatefulWidget {
  const OnboardReadiness({super.key});

  /// SharedPreferences key holding how many times the user has completed
  /// onboarding (reached this readiness page). The splash reads it: after
  /// [maxFreeRuns] completed runs, launches go straight to the paywall
  /// instead of replaying the funnel.
  static const String onboardingRunsKey = 'onboarding_runs_completed';

  /// Free onboarding run-throughs before the splash sends the user
  /// straight to the paywall.
  static const int maxFreeRuns = 2;

  @override
  State<OnboardReadiness> createState() => _OnboardReadinessState();
}

class _OnboardReadinessState extends State<OnboardReadiness>
    with TickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _green = Color(0xFF639922);
  static const Color _amber = Color(0xFFEF9F27);
  static const Color _red = Color(0xFFE24B4A);
  static const Color _eyeRed = Color(0xFFE24B4A);

  /// Refresher gate — the one cell that gets the $2.99 route.
  static const int _refresherMinCorrect = 8;
  static const double _refresherMinAvgStars = 4.0;

  // ── FSME animated eyes ──────────────────────────────────────────────
  int _gazeTarget = 0;
  double _gazeCurrent = 0.0;
  Timer? _gazeTimer;
  late AnimationController _gazeAnim;
  late AnimationController _blinkController;
  Timer? _blinkTimer;
  final math.Random _rng = math.Random();

  /// Terminal lines revealed so far (typed in one at a time).
  final List<String> _lines = [];

  DiagnosticResult get _result =>
      OnboardingAnswers.instance.diagnosticResult ?? const DiagnosticResult([]);

  // ── Bands ───────────────────────────────────────────────────────────

  /// Band key on readinessScore: 0 = get to work, 1 = almost, 2 = ready.
  int get _band {
    final s = _result.readinessScore;
    if (s >= 80) return 2;
    if (s >= 65) return 1;
    return 0;
  }

  Color get _bandColor {
    switch (_band) {
      case 2:
        return _green;
      case 1:
        return _amber;
      default:
        return _red;
    }
  }

  String get _bandTag {
    switch (_band) {
      case 2:
        return 'READY';
      case 1:
        return 'ALMOST READY';
      default:
        return 'KEEP GOING';
    }
  }

  /// Confidence tier: 0 = Low (<3), 1 = Mid (3–4), 2 = High (>4).
  int get _confTier {
    final a = _result.avgStars;
    if (a < 3) return 0;
    if (a <= 4) return 1;
    return 2;
  }

  /// Knowledge tier: 0 = Low (≤5), 1 = Mid (6–7), 2 = High (8–10).
  int get _knowTier {
    final c = _result.correct;
    if (c <= 5) return 0;
    if (c <= 7) return 1;
    return 2;
  }

  bool get _recommendRefresher =>
      _result.correct >= _refresherMinCorrect &&
      _result.avgStars > _refresherMinAvgStars;

  /// Assessment line per 3×3 cell [confTier][knowTier].
  String get _assessment {
    const grid = [
      // Low confidence
      [
        "Let's build your knowledge and confidence",
        'SafePrep is designed to build confidence and improve knowledge',
        'Excellent knowledge base, just lacking some confidence',
      ],
      // Mid confidence
      [
        'Confident at test taking — improve the knowledge base',
        'The perfect student for SafePrep: fast learner and confident',
        'One of the better scores — knows what they know, just needs '
            'to see real results',
      ],
      // High confidence
      [
        'Confident test taker, just needs to learn the material',
        'The perfect student for SafePrep: fast learner and very '
            'confident',
        'No need for a full study app — stay in tune with the Refresher',
      ],
    ];
    return grid[_confTier][_knowTier];
  }

  /// Recommendation line per 3×3 cell [confTier][knowTier].
  String get _recommendation {
    const grid = [
      // Low confidence
      [
        'Full study plan',
        'Full study plan + 60-Second Trainers',
        'Build confidence with a targeted study plan + 60-Second '
            'Trainers',
      ],
      // Mid confidence
      [
        'Full study course — prepared in less than 4 hours',
        'Targeted study course, reinforce with 60-Second Trainers',
        'Targeted study course, reinforce with 60-Second Trainers',
      ],
      // High confidence
      [
        'Full study course, then drive home results with 60-Second '
            'Trainers',
        'Start with targeted study, reinforce with 60-Second Trainers',
        'Move to the SafePrep Refresher — powerful, and designed just '
            'for you',
      ],
    ];
    return grid[_confTier][_knowTier];
  }

  // ── Lifecycle ───────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

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

    MixpanelService.instance.track(
      'SpOn_Ready_Viewed',
      properties: {
        'app_name': 'SP',
        'band': _bandTag,
        'readiness_score': _result.readinessScore,
        'conf_tier': _confTier,
        'know_tier': _knowTier,
        'refresher_eligible': _recommendRefresher,
      },
    );

    _recordOnboardingRun();
    _revealLines();
  }

  /// Reaching this screen counts as one completed onboarding run — the
  /// splash uses the tally to cap free runs. See
  /// [OnboardReadiness.onboardingRunsKey] / [OnboardReadiness.maxFreeRuns].
  Future<void> _recordOnboardingRun() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(OnboardReadiness.onboardingRunsKey) ?? 0;
    await prefs.setInt(OnboardReadiness.onboardingRunsKey, current + 1);
  }

  /// Types the terminal readout in one line at a time.
  Future<void> _revealLines() async {
    final avg = _result.avgStars.toStringAsFixed(1);
    final knowPct = _result.correct * 10;

    final script = <String>[
      'Confidence level $avg',
      'Knowledge level $knowPct%',
      'Assessment: $_assessment',
      'Recommend: $_recommendation',
    ];

    await Future.delayed(const Duration(milliseconds: 400));
    for (final line in script) {
      if (!mounted) return;
      setState(() => _lines.add(line));
      await Future.delayed(const Duration(milliseconds: 700));
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

  @override
  void dispose() {
    _gazeAnim.dispose();
    _blinkController.dispose();
    _gazeTimer?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }

  void _next() {
    final bool refresher = _recommendRefresher;

    MixpanelService.instance.track(
      'SpOn_Ready_Continue',
      properties: {
        'app_name': 'SP',
        'band': _bandTag,
        'readiness_score': _result.readinessScore,
        'tier': refresher ? 'refresher' : 'sp',
      },
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OnboardPaywall(isRefresher: refresher)),
    );
  }

  // ── FSME eye ────────────────────────────────────────────────────────

  Widget _davEye() {
    return AnimatedBuilder(
      animation: Listenable.merge([_gazeAnim, _blinkController]),
      builder: (context, _) {
        final blink = 1.0 - _blinkController.value * 0.92;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(1.0, blink),
          child: Container(
            width: 40,
            height: 40,
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
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: _eyeRed.withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Transform.translate(
                offset: Offset(_gazeCurrent * 7, 1),
                child: Container(
                  width: 13,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0000),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// FSME readout box — animated eyes + typed terminal lines. The
  /// Assessment and Recommend lines render in the band color so the
  /// verdict reads at a glance; the two data lines stay gold.
  Widget _fsmeBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _davEye(),
            const SizedBox(width: 16),
            Text(
              'F S M E',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 3,
                color: _eyeRed.withValues(alpha: 0.3),
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(width: 16),
            _davEye(),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _gold.withValues(alpha: 0.4), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final line in _lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    '> $line',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      height: 1.5,
                      color:
                          (line.startsWith('Assessment:') ||
                              line.startsWith('Recommend:'))
                          ? _bandColor
                          : _gold.withValues(alpha: 0.85),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final int score = _result.readinessScore;

    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              Text(
                'YOUR READINESS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _gold.withValues(alpha: 0.8),
                  letterSpacing: 1.6,
                ),
              ),

              const SizedBox(height: 20),

              // ── Score ring ────────────────────────────────────────
              Center(
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _bandColor.withValues(alpha: 0.10),
                    border: Border.all(color: _bandColor, width: 2.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$score%',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          color: _bandColor,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _bandTag,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _bandColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 26),

              // ── FSME readout ──────────────────────────────────────
              _fsmeBox(),

              const SizedBox(height: 28),

              // ── CTA ───────────────────────────────────────────────
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _next,
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
                  child: Text(
                    _recommendRefresher
                        ? 'See the Refresher  \u2192'
                        : 'Build my study plan  \u2192',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
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
