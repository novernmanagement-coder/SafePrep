import 'package:flutter/material.dart';
import '../constants.dart';
import '../mixpanel_service.dart';
import 'onboard_diagnostic.dart';

/// Onboarding screen 4 of 5 — the beat before the diagnostic.
///
/// Two jobs, and they pull against each other on purpose. "A quick
/// 10-question quiz" lowers the barrier to starting; "let's see where you
/// actually stand" quietly warns that their self-assessment is about to be
/// audited. The word *actually* is doing that work — don't soften it.
///
/// Deliberately does NOT say what most people score. Pre-announcing an
/// expected result defuses the sting when the real number lands.
class OnboardQuizIntro extends StatefulWidget {
  const OnboardQuizIntro({super.key});

  @override
  State<OnboardQuizIntro> createState() => _OnboardQuizIntroState();
}

class _OnboardQuizIntroState extends State<OnboardQuizIntro> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);

  bool _starting = false;

  @override
  void initState() {
    super.initState();
    MixpanelService.instance.track(
      'onboarding_quiz_intro_viewed',
      properties: {'app_name': 'SP'},
    );
  }

  Future<void> _startQuiz() async {
    if (_starting) return;
    setState(() => _starting = true);

    MixpanelService.instance.track(
      'onboarding_diagnostic_started',
      properties: {'app_name': 'SP'},
    );

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OnboardDiagnostic()),
    );

    // Re-enable if they back out of the quiz.
    if (mounted) setState(() => _starting = false);
  }

  /// Header row: back chevron, centred progress, balancing spacer.
  Widget _header(int filled) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            alignment: Alignment.centerLeft,
            icon: Icon(
              Icons.chevron_left,
              size: 24,
              color: _softWhite.withValues(alpha: 0.4),
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return Container(
                width: 22,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: i < filled
                      ? _gold
                      : _softWhite.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 32),
      ],
    );
  }

  /// One line in the expectations box.
  Widget _detail(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, size: 17, color: _gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                color: _softWhite.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(4),

              const SizedBox(height: 26),

              // ── Mark ──────────────────────────────────────────────
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _gold.withValues(alpha: 0.06),
                    border: Border.all(
                      color: _gold.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.assignment_outlined,
                    size: 26,
                    color: _gold,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'NEXT UP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _gold,
                  letterSpacing: 1.6,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'A quick 10-question\nServSafe quiz',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  color: _softWhite,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                "Let's see where you actually stand.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: _softWhite.withValues(alpha: 0.6),
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 24),

              // ── What to expect ────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 5),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _gold.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _detail(
                      Icons.center_focus_strong_outlined,
                      'Real questions from the exam',
                    ),
                    _detail(Icons.schedule, 'About 2 minutes'),
                    _detail(Icons.bar_chart, "You'll get a readiness score"),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── CTA ───────────────────────────────────────────────
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _starting ? null : _startQuiz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: _darkBg,
                    disabledBackgroundColor: _gold.withValues(alpha: 0.6),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.buttonCornerRadius,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Start quiz  \u2192',
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
