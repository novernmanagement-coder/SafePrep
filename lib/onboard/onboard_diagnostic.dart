import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants.dart';
import '../mixpanel_service.dart';
import 'onboard_answers.dart';
import 'onboard_diagnostic_questions.dart';
import 'onboard_category_score.dart';

/// Onboarding screen 5 of 5 — the diagnostic.
///
/// Renders in whichever mode the user picked on screen 3. That isn't
/// cosmetic: the promise made two screens ago was that we'd set their
/// questions up their way, and this is where it either happens or the
/// promise was a lie.
///
///   explanations  — green/red plus a per-question explanation
///   answersOnly   — green/red, no explanation
///   quizFormat    — no feedback at all; everything lands on the results
///                   screen instead
///
/// After each answer, a 5-star confidence capture appears before
/// feedback or advance. The stars feed the weighted readiness score
/// (high-confidence wrong = 0 points, the conversion moment) and the
/// calibration label on the results screen. Every data point the
/// readiness screen references is captured here — nothing invented.
///
/// Q1 ONLY: after the confidence star is tapped, the FSME character
/// (animated red eyeballs + terminal box) takes over. It reacts to the
/// star level, announces an incoming call, bails, and we overhear his
/// side of it. Then a Continue button (Q1 only) advances to Q2 — no
/// auto-advance, no Next button. FSME does not appear again for the rest
/// of the diagnostic. It's a one-time personality beat, not a
/// per-question feature.
///
/// Timer is deliberately absent. A countdown would make people rush, and
/// a rushed answer measures reaction time rather than knowledge — which
/// would corrupt the category gap map the whole plan is built from.
class OnboardDiagnostic extends StatefulWidget {
  const OnboardDiagnostic({super.key});

  @override
  State<OnboardDiagnostic> createState() => _OnboardDiagnosticState();
}

/// Who an FSME line is directed at / how it renders. Matches the system
/// used on the intro, exam-date, study-style, and quiz-intro screens.
/// - user: FSME's default voice (gold)
/// - boss: directed at the boss (blue)
/// - self: muttering/thinking to himself (gray)
/// - processing: system-status bits — teal
/// [flash] marks the "sudden real expertise" beat — bold gold.
/// [isCall] is this page's own special case (the incoming-call line) —
/// renders red regardless of audience, kept separate from the 4-way
/// system since it's a one-off dramatic beat, not a recurring voice.
enum _FsmeAudience { user, boss, self, processing }

class _FsmeLine {
  final String text;
  final _FsmeAudience audience;
  final bool flash;
  final bool isCall;
  const _FsmeLine(
    this.text, {
    this.audience = _FsmeAudience.user,
    this.flash = false,
    this.isCall = false,
  });
}

class _OnboardDiagnosticState extends State<OnboardDiagnostic>
    with TickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _green = Color(0xFF639922);
  static const Color _red = Color(0xFFE24B4A);
  static const Color _eyeRed = Color(0xFFE24B4A);
  // Matches the boss-line / self-line / processing colors used across
  // the rest of the funnel.
  static const Color _bossBlue = Color(0xFF4A9BE2);
  static const Color _selfGray = Color(0xFF9E9E9E);
  static const Color _processingTeal = Color(0xFF6FA8A6);

  int _index = 0;
  int? _picked;

  /// Set when the user taps a star. Null means the star row is waiting
  /// for input — feedback and the Next button won't show until this is
  /// set, so the confidence capture is not skippable.
  int? _confidence;

  final List<bool> _answers = [];
  final List<int> _confidenceRatings = [];

  // ── FSME (Q1 only) ─────────────────────────────────────────────────
  /// True once the Q1 star is tapped — drives the FSME takeover. While
  /// this is on, the normal advance/Next path is suppressed on Q1.
  bool _fsmeActive = false;

  /// True once the FSME reaction has printed its last line. Gates the
  /// Q1 Continue button so it only appears after the gag finishes.
  bool _fsmeDone = false;

  /// Lines revealed so far in the FSME terminal box.
  final List<_FsmeLine> _fsmeLines = [];

  /// Eye gaze: -1 left, 0 center, 1 right. Held center, occasional darts.
  int _gazeTarget = 0;
  double _gazeCurrent = 0.0;
  Timer? _gazeTimer;
  late AnimationController _gazeAnim;

  // Eye blink.
  late AnimationController _blinkController;
  Timer? _blinkTimer;

  final math.Random _rng = math.Random();

  /// Confidence line keyed to the star the user tapped on Q1.
  static const Map<int, String> _confidenceLines = {
    1: 'Basically a guess',
    2: 'Low confidence but something tells me this answer is at least close',
    3: 'I can eliminate the obvious and expect my answer is correct',
    4: 'I know this is correct, very little hesitation',
    5: 'No hesitation... my answer IS correct',
  };

  /// Opening beat, shown the moment Q1 is answered. Replaces the old
  /// "professional / serious face" bit with the boss's-pride-and-joy
  /// framing plus a self-talk backstory line — the moment he lost the
  /// promotion to her. Ends with the same star-legend handoff as before.
  static const List<_FsmeLine> _openingScript = [
    _FsmeLine('Ok, you selected your answer \u2014 now choose a star rating'),
    _FsmeLine('based on how confident you are with your answer.'),
    _FsmeLine("FYI, this is the boss's pride and joy."),
    _FsmeLine(
      'I was just going to make a cookie-cutter,',
      audience: _FsmeAudience.self,
    ),
    _FsmeLine(
      'take-a-quiz-repeat app with 1,000 useless questions',
      audience: _FsmeAudience.self,
    ),
    _FsmeLine(
      'that have little to do with the exam.',
      audience: _FsmeAudience.self,
    ),
    _FsmeLine(
      'She presented this sleek, user-friendly adaptive',
      audience: _FsmeAudience.self,
    ),
    _FsmeLine(
      'engine app... she got promoted, and now I work for her.',
      audience: _FsmeAudience.self,
    ),
    _FsmeLine("Do your best, keep it real, and the boss will give you"),
    _FsmeLine("her feedback. Don't forget to choose a star rating."),
    _FsmeLine('1 = basically a guess.'),
    _FsmeLine('2 = low confidence, but it feels at least close.'),
    _FsmeLine("3 = eliminate the obvious, expect you're right."),
    _FsmeLine("4 = you know it's right, very little hesitation."),
    _FsmeLine('5 = no hesitation — your answer IS correct.'),
  ];

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
      if (!mounted || !_fsmeActive) return;
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
      if (!mounted || !_fsmeActive) return;
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

  /// Falls back to the most informative mode if screen 3 was somehow
  /// skipped — better to over-explain than to show a bare score.
  StudyStyle get _style =>
      OnboardingAnswers.instance.studyStyle ?? StudyStyle.explanations;

  DiagnosticQuestion get _q => kDiagnosticQuestions[_index];
  bool get _isAnswered => _picked != null;
  bool get _hasConfidence => _confidence != null;
  bool get _isLast => _index == kDiagnosticQuestions.length - 1;
  bool get _isFirst => _index == 0;

  void _pick(int optionIndex) {
    if (_isAnswered) return;

    final bool wasCorrect = optionIndex == _q.correctIndex;
    setState(() {
      _picked = optionIndex;
      _answers.add(wasCorrect);
    });

    MixpanelService.instance.track(
      'SpOn_Diag_Answered',
      properties: {
        'app_name': 'SP',
        'question_number': _index + 1,
        'category': _q.category,
        'correct': wasCorrect,
      },
    );

    // Q1: FSME appears the moment the answer is picked, opening with an
    // explanation of the star system. The stars then sit below his box;
    // tapping one prints his reaction and reveals the Continue button.
    if (_isFirst) {
      _openFsme();
    }
  }

  /// Opening beat — box appears with the star-system explanation, then
  /// the star row renders below it (see build). No advance yet; that
  /// waits for the star tap in [_setConfidence].
  Future<void> _openFsme() async {
    setState(() {
      _fsmeActive = true;
      _fsmeDone = false;
      _fsmeLines.clear();
    });
    _scheduleGaze();
    _scheduleBlink();

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _fsmeLines.addAll(_openingScript);
    });
  }

  void _setConfidence(int stars) {
    if (_hasConfidence) return;

    setState(() {
      _confidence = stars;
      _confidenceRatings.add(stars);
    });

    MixpanelService.instance.track(
      'SpOn_Diag_Confidence',
      properties: {
        'app_name': 'SP',
        'question_number': _index + 1,
        'stars': stars,
        'correct': _answers.last,
      },
    );

    // Q1: FSME is already on screen (opened at pick). The star tap prints
    // his reaction lines, then reveals the Continue button.
    if (_isFirst) {
      _runFsmeReaction(stars);
      return;
    }

    // Quiz format shows no feedback, so advance after a short beat.
    if (!_style.showsImmediateFeedback) {
      Future.delayed(const Duration(milliseconds: 140), _advance);
    }
  }

  /// Q1 star-tap beat. The opening star-system line is already showing.
  /// This appends the confidence reaction, then the call gag, one line at
  /// a time. When the last line lands, [_fsmeDone] flips true and the
  /// Continue button appears — the user advances on their own tap.
  Future<void> _runFsmeReaction(int stars) async {
    final lines = <_FsmeLine>[
      _FsmeLine(
        _confidenceLines[stars] ?? 'Basically a guess',
        audience: _FsmeAudience.processing,
      ),
      const _FsmeLine(
        "I have a call coming in... you're on your own",
        isCall: true,
      ),
      const _FsmeLine(
        "Hello... FSME here. No, I don't want to renew my subscription "
        'to Byte Me Quarterly',
      ),
    ];

    await Future.delayed(const Duration(milliseconds: 400));
    for (final line in lines) {
      if (!mounted) return;
      setState(() => _fsmeLines.add(line));
      await Future.delayed(const Duration(milliseconds: 1100));
    }

    // Reaction finished — reveal the Continue button and let the user
    // move on when they're ready.
    if (!mounted) return;
    setState(() => _fsmeDone = true);
  }

  void _advance() {
    if (!mounted) return;

    if (_isLast) {
      final result = DiagnosticResult(
        List<bool>.from(_answers),
        confidence: List<int>.from(_confidenceRatings),
      );
      OnboardingAnswers.instance.diagnosticResult = result;

      MixpanelService.instance.track(
        'SpOn_Diag_Completed',
        properties: {
          'app_name': 'SP',
          'score': result.correct,
          'weighted_score': result.weightedScore,
          'calibration': result.calibrationLabel,
          'study_style': _style.tag,
        },
      );

      // pushReplacement so Back from the results doesn't drop them into
      // a finished quiz they can't retake.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardCategoryScore()),
      );
      return;
    }

    setState(() {
      _index++;
      _picked = null;
      _confidence = null;
      _fsmeActive = false;
      _fsmeDone = false;
      _fsmeLines.clear();
    });
  }

  /// Progress bar plus position and category labels.
  Widget _progressHeader() {
    final double pct = (_index + 1) / kDiagnosticQuestions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'QUESTION ${_index + 1} OF ${kDiagnosticQuestions.length}',
              style: TextStyle(
                fontSize: 11,
                color: _softWhite.withValues(alpha: 0.5),
                letterSpacing: 0.6,
              ),
            ),
            Text(
              _q.category,
              style: TextStyle(
                fontSize: 11,
                color: _gold.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 3,
            backgroundColor: _softWhite.withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation<Color>(_gold),
          ),
        ),
      ],
    );
  }

  /// One answer option. Colour only appears after confidence is given
  /// (in feedback modes), so the star step sits cleanly between the pick
  /// and the reveal.
  Widget _option(int i) {
    final bool showFeedback = _hasConfidence && _style.showsImmediateFeedback;
    final bool isCorrect = i == _q.correctIndex;
    final bool isPicked = i == _picked;

    Color border = _gold.withValues(alpha: 0.3);
    Color fill = _cardBg;
    Color text = _softWhite;
    IconData? trailing;
    Color trailingColor = _gold;

    if (showFeedback) {
      if (isCorrect) {
        border = _green;
        fill = _green.withValues(alpha: 0.12);
        text = const Color(0xFFC0DD97);
        trailing = Icons.check;
        trailingColor = const Color(0xFFC0DD97);
      } else if (isPicked) {
        border = _red;
        fill = _red.withValues(alpha: 0.12);
        text = const Color(0xFFF09595);
        trailing = Icons.close;
        trailingColor = const Color(0xFFF09595);
      } else {
        border = _softWhite.withValues(alpha: 0.1);
        text = _softWhite.withValues(alpha: 0.45);
      }
    } else if (_isAnswered && isPicked) {
      // Answer selected, waiting for confidence — acknowledge the tap
      // without revealing anything yet.
      border = _gold;
      fill = _gold.withValues(alpha: 0.12);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _pick(i),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: border,
                width: showFeedback && (isCorrect || isPicked) ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _q.options[i],
                    style: TextStyle(
                      fontSize: 13.5,
                      color: text,
                      height: 1.35,
                      fontWeight: showFeedback && (isCorrect || isPicked)
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Icon(trailing, size: 17, color: trailingColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Five tappable stars. Appears after the answer is picked, before
  /// feedback. One tap, not skippable — the readiness score needs it.
  Widget _starRow() {
    return AnimatedOpacity(
      opacity: _isAnswered && !_hasConfidence ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Column(
          children: [
            Text(
              'Your confidence with this answer',
              style: TextStyle(
                fontSize: 12,
                color: _softWhite.withValues(alpha: 0.5),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final starNumber = i + 1;
                return GestureDetector(
                  onTap: () => _setConfidence(starNumber),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.star_outline_rounded,
                      size: 32,
                      color: _gold.withValues(alpha: 0.5),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// Locked-in star display — shows after the user taps, replacing the
  /// interactive row with a static read of what they chose.
  Widget _starResult() {
    if (!_hasConfidence) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        children: [
          Text(
            'Your confidence with this answer',
            style: TextStyle(
              fontSize: 12,
              color: _softWhite.withValues(alpha: 0.5),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _confidence!;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 32,
                  color: filled ? _gold : _gold.withValues(alpha: 0.2),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// One glowing red eyeball that darts and blinks. Resized to match the
  /// intro/exam-date/study-style/quiz-intro spec (26x26, 8x10 pupil).
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

  /// FSME takeover box (Q1 only) — animated eyes + terminal readout that
  /// fills in one line at a time. Color follows [line.audience]; the
  /// call line renders red via [line.isCall] regardless of audience.
  Widget _fsmeBox() {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
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
                for (final line in _fsmeLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '> ${line.text}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.5,
                        fontWeight: line.flash
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: line.isCall
                            ? _eyeRed.withValues(alpha: 0.9)
                            : switch (line.audience) {
                                _FsmeAudience.boss => _bossBlue,
                                _FsmeAudience.self => _selfGray,
                                _FsmeAudience.processing => _processingTeal,
                                _FsmeAudience.user => _gold.withValues(
                                  alpha: 0.8,
                                ),
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

  @override
  Widget build(BuildContext context) {
    // Q2+ Next button (feedback modes). Q1 never uses this path — it has
    // its own Continue button gated on the FSME gag finishing.
    final bool showNext =
        _hasConfidence && _style.showsImmediateFeedback && !_isFirst;

    // Q1 Continue button — appears only after the FSME reaction prints
    // its last line.
    final bool showFirstContinue = _isFirst && _fsmeDone;

    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _progressHeader(),

              const SizedBox(height: 22),

              Text(
                _q.question,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _softWhite,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 20),

              for (var i = 0; i < _q.options.length; i++) _option(i),

              // Q1: FSME box appears the moment the answer is picked,
              // opening with the star-system explanation. The star row
              // then renders BELOW his box.
              if (_isFirst && _fsmeActive) _fsmeBox(),

              // Star capture: appears after pick, before feedback. On Q1
              // it sits under the FSME box; the reaction lines append when
              // a star is tapped.
              if (_isAnswered && !_hasConfidence) _starRow(),
              if (_hasConfidence) _starResult(),

              // Explanation (feedback modes, not Q1 while FSME runs).
              if (_hasConfidence &&
                  _style.showsImmediateFeedback &&
                  _style.showsExplanations &&
                  !_isFirst)
                _explanation(),

              // Q1 Continue button — user-driven advance to Q2 once the
              // FSME gag has finished playing.
              if (showFirstContinue) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _advance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _darkBg,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.buttonCornerRadius,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Continue  \u2192',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],

              if (showNext) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _advance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _darkBg,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.buttonCornerRadius,
                        ),
                      ),
                    ),
                    child: Text(
                      _isLast
                          ? 'See my results  \u2192'
                          : 'Next question  \u2192',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The "why" block — explanations mode only.
  Widget _explanation() {
    return Container(
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: const BoxDecoration(
        color: _cardBg,
        border: Border(left: BorderSide(color: _gold, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'WHY',
            style: TextStyle(
              fontSize: 11,
              color: _gold,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _q.explanation,
            style: TextStyle(
              fontSize: 12,
              color: _softWhite.withValues(alpha: 0.7),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
