import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants.dart';
import '../mixpanel_service.dart';
import 'onboard_answers.dart';
import 'onboard_diagnostic_questions.dart';
import 'onboard_readiness.dart';

/// Results, beat 1 of 2 — the category breakdown.
///
/// Deliberately does NOT show the overall readiness number. The categories
/// build the case; the button makes the user ask for the verdict; the
/// readiness screen delivers it. Handing over the score here collapses two
/// beats into one and loses the moment.
///
/// ── On the numbers ────────────────────────────────────────────────────
/// Ten questions across six categories means one or two questions each.
/// Raw correct/incorrect can only produce 0%, 50%, 100% — useless for
/// a gap map. The confidence stars fix this: each question contributes
/// 0–10 weighted points, so a 2-question category has 21 possible
/// values (0–20 = 0%–100% in 5% increments). Honest granularity from
/// data the user supplied, not invented percentages.
///
/// Each category also gets a qualitative label — Confident / Mixed /
/// Unsure — so the read is instant even if the user ignores the numbers.
///
/// FSME pops up once, between the deadline box and the button: a single
/// typed-out line ("Dude, you did it...") that hands off to the Boss for
/// the readiness verdict on the next screen. Standard pop-in timing (2s
/// delay, 2300ms fade), then holds visible for 3 seconds once typed.
class OnboardCategoryScore extends StatefulWidget {
  const OnboardCategoryScore({super.key});

  @override
  State<OnboardCategoryScore> createState() => _OnboardCategoryScoreState();
}

class _OnboardCategoryScoreState extends State<OnboardCategoryScore>
    with TickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _green = Color(0xFF639922);
  static const Color _amber = Color(0xFFEF9F27);
  static const Color _red = Color(0xFFE24B4A);
  static const Color _eyeRed = Color(0xFFE24B4A);

  /// Rough minutes of targeted work per weak category. Tunable — this is
  /// what produces the "X minutes a day" line and it should stay
  /// consistent with the under-4-hours promise.
  static const int _minutesPerWeakCategory = 40;

  /// Hard ceiling on the estimate, in minutes. The promise is four hours.
  static const int _maxEstimateMinutes = 240;

  // ── FSME pop-up ───────────────────────────────────────────────────
  static const String _fsmeLine =
      "Cool, the boss isn't here. Dude, you did it... Boss will give "
      "you her findings then we go get that LARGE combo";

  bool _fsmeVisible = false;
  String _fsmeTyped = '';
  Timer? _fsmeInTimer;
  Timer? _fsmeOutTimer;
  Timer? _fsmeTypeTimer;

  int _gazeTarget = 0;
  double _gazeCurrent = 0.0;
  Timer? _gazeTimer;
  late AnimationController _gazeAnim;
  late AnimationController _blinkController;
  Timer? _blinkTimer;
  final math.Random _rng = math.Random();

  DiagnosticResult get _result =>
      OnboardingAnswers.instance.diagnosticResult ?? const DiagnosticResult([]);

  ExamWindow? get _window => OnboardingAnswers.instance.examWindow;

  @override
  void initState() {
    super.initState();
    MixpanelService.instance.track(
      'SpOn_Cat_Viewed',
      properties: {'app_name': 'SP', 'score': _result.correct},
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

    // Standard pop-in timing: 2s delay, then the fade transition itself
    // takes 2300ms (see _fsmePopup's AnimatedOpacity).
    _fsmeInTimer = Timer(const Duration(seconds: 2), _startFsme);
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
      await _blinkController.forward(from: 0.0);
      if (mounted) await _blinkController.reverse();
      _scheduleBlink();
    });
  }

  /// Fade in, type the line (user-audience, per the standing typing
  /// rule), then hold visible for 3 seconds once fully typed.
  void _startFsme() {
    if (!mounted) return;
    setState(() => _fsmeVisible = true);
    _scheduleGaze();
    _scheduleBlink();

    int i = 0;
    _fsmeTypeTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
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
        // Hold for 3 seconds once fully typed, then fade out.
        _fsmeOutTimer = Timer(const Duration(seconds: 3), () {
          if (!mounted) return;
          setState(() => _fsmeVisible = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _fsmeInTimer?.cancel();
    _fsmeOutTimer?.cancel();
    _fsmeTypeTimer?.cancel();
    _gazeAnim.dispose();
    _blinkController.dispose();
    _gazeTimer?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }

  void _next() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OnboardReadiness()),
    );
  }

  /// Total estimated study minutes, from the number of weak categories.
  int get _estimateMinutes {
    final weak = _result.weakestCategories.length;
    final raw = weak * _minutesPerWeakCategory;
    return raw > _maxEstimateMinutes ? _maxEstimateMinutes : raw;
  }

  Color _colorForScore(int score) {
    if (score >= 70) return _green;
    if (score >= 40) return _amber;
    return _red;
  }

  Color _colorForLabel(String label) {
    switch (label) {
      case 'Confident':
        return _green;
      case 'Mixed':
        return _amber;
      default:
        return _red;
    }
  }

  /// One category row — name, weighted score, qualitative label, and a
  /// bar filled to the score.
  Widget _categoryRow(String category, int score, String label) {
    final Color barColor = _colorForScore(score);
    final Color labelColor = _colorForLabel(label);

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(fontSize: 12.5, color: _softWhite),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$score%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 5,
              backgroundColor: _softWhite.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  /// Deadline box. Pacing only makes sense with a date — "not scheduled"
  /// gets a proctor nudge instead, since that user is a booking lead.
  Widget _deadlineBox() {
    final int? days = _window?.daysToExam;
    final bool scheduled = days != null;

    final String headline = scheduled
        ? 'Your exam is in $days day${days == 1 ? '' : 's'}'
        : 'No exam booked yet';

    String body;
    if (scheduled) {
      final int perDay = (_estimateMinutes / days).ceil();
      body =
          'Closing your weakest areas takes about '
          '$perDay minutes a day.';
    } else {
      body =
          'Get ready first, then book a proctor. '
          'About ${_estimateMinutes ~/ 60} hr '
          '${_estimateMinutes % 60} min of work from here.';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gold.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                scheduled ? Icons.event_outlined : Icons.event_busy_outlined,
                size: 17,
                color: _gold,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _softWhite,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 12,
              color: _softWhite.withValues(alpha: 0.6),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  /// FSME's eye — matches the 26x26 spec used across the rest of the
  /// funnel.
  Widget _davEye() {
    return AnimatedBuilder(
      animation: Listenable.merge([_gazeAnim, _blinkController]),
      builder: (context, _) {
        final blink = 1.0 - _blinkController.value * 0.92;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(1.0, blink),
          child: Container(
            width: 26,
            height: 26,
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
                offset: Offset(_gazeCurrent * 5, 0.5),
                child: Container(
                  width: 8,
                  height: 10,
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

  /// FSME pop-up — eyes + typed line. Standard pop-in timing: appears
  /// 2s after the screen loads, fade transition takes 2300ms, then the
  /// line types out and holds visible.
  Widget _fsmePopup() {
    return AnimatedOpacity(
      opacity: _fsmeVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 2300),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _gold.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: _davEye()),
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
                  color: _gold.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scores = _result.categoryWeightedScore;
    final labels = _result.categoryLabel;

    // Strongest first so the read descends into the problem, landing on
    // the weakest category right above the deadline box.
    final categories = scores.keys.toList()
      ..sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));

    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Your category score',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _softWhite,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'From the ${kDiagnosticQuestions.length} questions you just '
                'answered.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: _softWhite.withValues(alpha: 0.55),
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 24),

              for (final c in categories)
                _categoryRow(c, scores[c] ?? 0, labels[c] ?? 'Unsure'),

              const SizedBox(height: 8),

              _deadlineBox(),

              _fsmePopup(),

              const SizedBox(height: 20),

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
                  child: const Text(
                    'See my readiness score  \u2192',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
