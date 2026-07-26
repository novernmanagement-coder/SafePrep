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
/// Timer is deliberately absent. A countdown would make people rush, and
/// a rushed answer measures reaction time rather than knowledge — which
/// would corrupt the category gap map the whole plan is built from.
class OnboardDiagnostic extends StatefulWidget {
  const OnboardDiagnostic({super.key});

  @override
  State<OnboardDiagnostic> createState() => _OnboardDiagnosticState();
}

class _OnboardDiagnosticState extends State<OnboardDiagnostic> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _green = Color(0xFF639922);
  static const Color _red = Color(0xFFE24B4A);

  int _index = 0;
  int? _picked;

  /// Set when the user taps a star. Null means the star row is waiting
  /// for input — feedback and the Next button won't show until this is
  /// set, so the confidence capture is not skippable.
  int? _confidence;

  final List<bool> _answers = [];
  final List<int> _confidenceRatings = [];

  /// Falls back to the most informative mode if screen 3 was somehow
  /// skipped — better to over-explain than to show a bare score.
  StudyStyle get _style =>
      OnboardingAnswers.instance.studyStyle ?? StudyStyle.explanations;

  DiagnosticQuestion get _q => kDiagnosticQuestions[_index];
  bool get _isAnswered => _picked != null;
  bool get _hasConfidence => _confidence != null;
  bool get _isLast => _index == kDiagnosticQuestions.length - 1;

  void _pick(int optionIndex) {
    if (_isAnswered) return;

    final bool wasCorrect = optionIndex == _q.correctIndex;
    setState(() {
      _picked = optionIndex;
      _answers.add(wasCorrect);
    });

    MixpanelService.instance.track(
      'onboarding_diagnostic_answered',
      properties: {
        'app_name': 'SP',
        'question_number': _index + 1,
        'category': _q.category,
        'correct': wasCorrect,
      },
    );
  }

  void _setConfidence(int stars) {
    if (_hasConfidence) return;

    setState(() {
      _confidence = stars;
      _confidenceRatings.add(stars);
    });

    MixpanelService.instance.track(
      'onboarding_diagnostic_confidence',
      properties: {
        'app_name': 'SP',
        'question_number': _index + 1,
        'stars': stars,
        'correct': _answers.last,
      },
    );

    // Quiz format shows no feedback, so advance after a short beat.
    if (!_style.showsImmediateFeedback) {
      Future.delayed(const Duration(milliseconds: 140), _advance);
    }
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
        'onboarding_diagnostic_completed',
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

  @override
  Widget build(BuildContext context) {
    final bool showNext = _hasConfidence && _style.showsImmediateFeedback;

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

              // Star capture: appears after pick, before feedback.
              if (_isAnswered && !_hasConfidence) _starRow(),
              if (_hasConfidence) _starResult(),

              if (showNext && _style.showsExplanations) _explanation(),

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
}
