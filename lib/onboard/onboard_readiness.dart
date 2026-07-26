import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants.dart';
import '../mixpanel_service.dart';
import 'onboard_answers.dart';
import 'onboard_diagnostic_questions.dart';
import 'onboard_paywall.dart';

/// Results, beat 2 of 2 — the readiness verdict.
///
/// A short calculating sequence types out what's being done with their
/// answers, then the score fills in on a ring. The theatre is doing real
/// work: it makes the number feel measured rather than assigned, and the
/// sequence states the passing threshold on the way past, so the gap is
/// already obvious by the time the score lands.
///
/// Every line in that sequence is literally true of data we hold. Nothing
/// here claims a capability the app doesn't have — no touch pressure, no
/// answer-change counts, no "decision process" label that nothing
/// computes. The confidence profile comes from the star ratings the user
/// tapped after each answer — their data, not ours.
class OnboardReadiness extends StatefulWidget {
  const OnboardReadiness({super.key});

  @override
  State<OnboardReadiness> createState() => _OnboardReadinessState();
}

class _OnboardReadinessState extends State<OnboardReadiness>
    with SingleTickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _green = Color(0xFF639922);

  /// ServSafe Manager passing score. 75%, not 70% — worth stating once
  /// here rather than scattering the number through copy.
  static const int kPassMark = 75;

  /// Minutes of targeted work per weak category, capped at the four-hour
  /// promise. Keep in step with the same constants on the category screen.
  static const int _minutesPerWeakCategory = 40;
  static const int _maxEstimateMinutes = 240;

  late AnimationController _ringController;
  late Animation<double> _ringAnim;

  final List<_CalcLine> _printed = [];
  bool _revealed = false;
  Timer? _typer;

  DiagnosticResult get _result =>
      OnboardingAnswers.instance.diagnosticResult ?? const DiagnosticResult([]);

  /// Confidence-weighted readiness score, 0–100.
  ///
  /// Factors in how sure the user was alongside whether they were right.
  /// A 5-star wrong scores 0; a 5-star correct scores 10. The composite
  /// can't be reverse-engineered from a mental count of correct answers,
  /// which is the point — it makes the number feel measured.
  int get _readiness => _result.weightedScore;

  /// High scorers get the Refresher offer, not the full plan. This
  /// checks raw accuracy (did they know the material?) rather than the
  /// weighted score (which folds in confidence). Someone who gets 8/10
  /// right but taps 1 star on everything shouldn't be sold a study plan.
  bool get _isPassing => _result.correct >= 8;

  int get _estimateMinutes {
    final raw = _result.weakestCategories.length * _minutesPerWeakCategory;
    return raw > _maxEstimateMinutes ? _maxEstimateMinutes : raw;
  }

  String get _estimateLabel {
    final h = _estimateMinutes ~/ 60;
    final m = _estimateMinutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h hr';
    return '$h hr $m min';
  }

  /// Verdict line, keyed off distance from the pass mark rather than a
  /// population average. The user's score is theirs; the only comparison
  /// on screen is the standard.
  String get _bandLine {
    if (_isPassing) return "You'd likely pass today";
    if (_readiness >= 60) return "You\u2019re at $_readiness% readiness";
    if (_readiness >= 45) return 'You know more than you think';
    return 'Starting fresh is fine';
  }

  String get _bandBody {
    if (_isPassing) {
      return "You're at $_readiness% readiness. What you "
          'need now is to stay sharp, not start over.';
    }
    if (_readiness >= 60) {
      return 'The good news is we can have you exam-ready '
          'quicker than you think.';
    }
    if (_readiness >= 45) {
      return "You're at $_readiness% readiness, and almost all of "
          'that gap sits in a few categories.';
    }
    return "You're at $_readiness% readiness. This is a teachable "
        'test, and it\u2019s what we teach.';
  }

  @override
  void initState() {
    super.initState();

    MixpanelService.instance.track(
      'onboarding_readiness_viewed',
      properties: {
        'app_name': 'SP',
        'score': _result.correct,
        'readiness': _readiness,
        'calibration': _result.calibrationLabel,
      },
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _ringAnim = CurvedAnimation(
      parent: _ringController,
      curve: Curves.easeOutCubic,
    );

    _startTyping();
  }

  @override
  void dispose() {
    _typer?.cancel();
    _ringController.dispose();
    super.dispose();
  }

  /// Lines are built from real values — question count, category count,
  /// their actual weakest area, and their confidence calibration — so
  /// nothing on screen is invented.
  ///
  /// The confidence profile line comes from the star ratings the user
  /// tapped after each answer. "overconfident" means they gave 4-5 stars
  /// on 2+ questions they got wrong. "underconfident" means 1-2 stars on
  /// 3+ they got right. "well-calibrated" means neither threshold hit.
  /// All three are defensible descriptions of data they supplied.
  List<_CalcLine> get _script {
    final weakest = _result.weakestCategories.isNotEmpty
        ? _result.weakestCategories.first.toLowerCase()
        : 'no gaps found';

    return [
      _CalcLine('> Reading ${kDiagnosticQuestions.length} responses'),
      _CalcLine(
        '  mapped to ${_result.categoryTotal.length} exam categories',
        dim: true,
      ),
      _CalcLine('> Building confidence profile'),
      _CalcLine('  calibration: ${_result.calibrationLabel}', dim: true),
      _CalcLine('> Weighting against exam blueprint'),
      _CalcLine('  $weakest flagged', dim: true),
      _CalcLine('> Comparing to passing threshold'),
      _CalcLine('  $kPassMark% required to pass', dim: true),
      _CalcLine('> Readiness calculated'),
    ];
  }

  void _startTyping() {
    final script = _script;
    int lineIndex = 0;
    int charIndex = 0;

    _typer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (lineIndex >= script.length) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          setState(() => _revealed = true);
          _ringController.forward();
        });
        return;
      }

      final source = script[lineIndex];

      setState(() {
        if (charIndex == 0) {
          _printed.add(_CalcLine('', dim: source.dim));
        }
        charIndex++;
        _printed[_printed.length - 1] = _CalcLine(
          source.text.substring(0, charIndex),
          dim: source.dim,
        );
      });

      if (charIndex >= source.text.length) {
        lineIndex++;
        charIndex = 0;
      }
    });
  }

  void _continue() {
    MixpanelService.instance.track(
      'onboarding_readiness_continue',
      properties: {
        'app_name': 'SP',
        'readiness': _readiness,
        'calibration': _result.calibrationLabel,
        'branch': _isPassing ? 'refresher_offer' : 'full_paywall',
      },
    );

    // High scorers get the $2.99 Refresher recommendation instead of the
    // full plan — selling someone a study plan they demonstrably don't
    // need is how you lose them.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardPaywall(isRefresher: _isPassing),
      ),
    );
  }

  Widget _calcBox() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 172),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gold.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in _printed)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                line.text,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.6,
                  color: line.dim ? _softWhite.withValues(alpha: 0.4) : _gold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ring() {
    return AnimatedBuilder(
      animation: _ringAnim,
      builder: (context, _) {
        final shown = (_readiness * _ringAnim.value).round();
        return SizedBox(
          width: 132,
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(132, 132),
                painter: _ReadinessRingPainter(
                  progress: (_readiness / 100) * _ringAnim.value,
                  arcColor: _isPassing ? _green : _gold,
                  trackColor: _softWhite.withValues(alpha: 0.1),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$shown%',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      color: _softWhite,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'READY',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.6,
                      color: _softWhite.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'READINESS ENGINE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.6,
                  color: _softWhite.withValues(alpha: 0.45),
                ),
              ),

              const SizedBox(height: 16),

              _calcBox(),

              AnimatedOpacity(
                opacity: _revealed ? 1 : 0,
                duration: const Duration(milliseconds: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),

                    Text(
                      'YOUR SCORE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                        color: _gold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Center(child: _ring()),

                    const SizedBox(height: 16),

                    Text(
                      _bandLine,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: _isPassing ? _green : _softWhite,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _bandBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _softWhite.withValues(alpha: 0.6),
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 18),

                    if (!_isPassing)
                      Container(
                        padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _gold.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_fire_department_outlined,
                              size: 18,
                              color: _gold,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: _softWhite.withValues(alpha: 0.75),
                                    height: 1.5,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: _estimateLabel,
                                      style: const TextStyle(
                                        color: _gold,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const TextSpan(
                                      text: ' of targeted work closes it.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 18),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _revealed ? _continue : null,
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
                          _isPassing
                              ? 'What I need  \u2192'
                              : 'Build my plan  \u2192',
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
            ],
          ),
        ),
      ),
    );
  }
}

class _CalcLine {
  final String text;
  final bool dim;
  const _CalcLine(this.text, {this.dim = false});
}

/// Track and progress arc. No pass-mark tick — the readiness score
/// stands on its own against 100, not against 75. A 63% ring that's
/// visibly short of full is more ominous than 63% with a tick nearby
/// showing you're almost at 75.
class _ReadinessRingPainter extends CustomPainter {
  final double progress; // 0..1
  final Color arcColor;
  final Color trackColor;

  _ReadinessRingPainter({
    required this.progress,
    required this.arcColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -math.pi / 2; // twelve o'clock

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, 2 * math.pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(_ReadinessRingPainter old) =>
      old.progress != progress || old.arcColor != arcColor;
}
