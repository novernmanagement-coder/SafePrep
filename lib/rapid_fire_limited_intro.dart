import 'package:flutter/material.dart';
import '../constants.dart';
import '../mixpanel_service.dart';
import 'onboard/onboard_answers.dart';
import 'onboard/onboard_diagnostic_questions.dart';
import 'rapid_fire_limited_page.dart';

/// Intro screen for the limited Rapid Fire — positioned between the
/// paywall decline and the actual tool. Its job is to make a free
/// offering feel like a gift rather than a consolation prize.
///
/// The copy frames the tool as special (category-specific, not random),
/// useful (60 seconds, anytime), and theirs to keep (unlimited access).
/// The category selection reinforces the "not just random questions"
/// promise — they pick what to study, which is the personalization
/// hook in miniature.
class RapidFireLimitedIntro extends StatelessWidget {
  const RapidFireLimitedIntro({super.key});

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);

  DiagnosticResult get _result =>
      OnboardingAnswers.instance.diagnosticResult ?? const DiagnosticResult([]);

  List<String> get _weakCategories {
    final cats = _result.weakestCategories;
    if (cats.length >= 3) return cats.take(3).toList();
    return [
      ...cats,
      if (!cats.contains('Time & Temperature')) 'Time & Temperature',
      if (!cats.contains('Cross-Contamination')) 'Cross-Contamination',
      if (!cats.contains('Personal Hygiene')) 'Personal Hygiene',
    ].take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 36, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),

              // Icon
              Icon(Icons.bolt_rounded, size: 40, color: _gold),

              const SizedBox(height: 14),

              // Eyebrow
              Text(
                'RAPID FIRE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w600,
                  color: _gold,
                ),
              ),

              const SizedBox(height: 14),

              // Headline
              Text(
                'Unlimited access to our most\npowerful retention tool.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _softWhite,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 16),

              // Body
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'This is a limited version of Rapid Fire \u2014 designed '
                  'to keep the material top of mind in 60 seconds or less. '
                  'Use it anytime during your training, right up until '
                  'you\u2019re ready to walk into the exam.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _softWhite.withValues(alpha: 0.55),
                    height: 1.6,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Feature callout
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _gold.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.tune_rounded, size: 20, color: _gold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Not just random questions. You choose the category '
                        'you want to refresh \u2014 every session is targeted '
                        'to what you need.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _softWhite.withValues(alpha: 0.6),
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Pre-selected categories
              Text(
                'We\u2019ve pre-selected your 3 weakest areas:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: _softWhite.withValues(alpha: 0.4),
                ),
              ),

              const SizedBox(height: 10),

              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: _weakCategories.map((cat) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _gold.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _gold,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 40),

              // Start button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    MixpanelService.instance.track(
                      'rapid_fire_limited_intro_start',
                      properties: {'app_name': 'SP'},
                    );

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RapidFireLimitedPage(),
                      ),
                    );
                  },
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
                    'Start Rapid Fire  \u2192',
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
