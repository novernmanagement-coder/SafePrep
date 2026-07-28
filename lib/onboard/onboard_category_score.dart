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
class OnboardCategoryScore extends StatefulWidget {
  const OnboardCategoryScore({super.key});

  @override
  State<OnboardCategoryScore> createState() => _OnboardCategoryScoreState();
}

class _OnboardCategoryScoreState extends State<OnboardCategoryScore> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _green = Color(0xFF639922);
  static const Color _amber = Color(0xFFEF9F27);
  static const Color _red = Color(0xFFE24B4A);

  /// Rough minutes of targeted work per weak category. Tunable — this is
  /// what produces the "X minutes a day" line and it should stay
  /// consistent with the under-4-hours promise.
  static const int _minutesPerWeakCategory = 40;

  /// Hard ceiling on the estimate, in minutes. The promise is four hours.
  static const int _maxEstimateMinutes = 240;

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
