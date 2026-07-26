import 'package:flutter/material.dart';
import '../mixpanel_service.dart';
import 'onboard_answers.dart';
import 'onboard_quiz_intro.dart';

/// Onboarding screen 3 of 5 — "How do you learn best?"
///
/// Sits BEFORE the diagnostic on purpose: the very next screen visibly
/// obeys the choice, which makes the personalization real instead of
/// theatre. Also a second easy tap before the harder ask of a 10-question
/// quiz.
class OnboardStudyStyle extends StatefulWidget {
  const OnboardStudyStyle({super.key});

  @override
  State<OnboardStudyStyle> createState() => _OnboardStudyStyleState();
}

class _OnboardStudyStyleState extends State<OnboardStudyStyle> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);

  StudyStyle? _selected;

  @override
  void initState() {
    super.initState();
    MixpanelService.instance.track(
      'onboarding_study_style_viewed',
      properties: {'app_name': 'SP'},
    );
  }

  Future<void> _choose(StudyStyle style) async {
    if (_selected != null) return; // ignore double taps mid-transition

    setState(() => _selected = style);

    OnboardingAnswers.instance.studyStyle = style;
    MixpanelService.instance.track(
      'onboarding_study_style_selected',
      properties: {'app_name': 'SP', 'study_style': style.tag},
    );

    final navigator = Navigator.of(context);

    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;

    await navigator.push(
      MaterialPageRoute(builder: (_) => const OnboardQuizIntro()),
    );

    // Clear the guard so the screen still works if they come back.
    if (mounted) setState(() => _selected = null);
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

  /// One tappable style option — icon, label, and a sub-line that sets
  /// expectations for how the diagnostic will behave.
  Widget _option({
    required StudyStyle style,
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    final bool isSelected = _selected == style;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _choose(style),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected ? _gold.withValues(alpha: 0.12) : _cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? _gold : _gold.withValues(alpha: 0.3),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 21, color: _gold),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _softWhite,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: _softWhite.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected ? Icons.check : Icons.chevron_right,
                  size: 18,
                  color: isSelected ? _gold : _gold.withValues(alpha: 0.6),
                ),
              ],
            ),
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
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(3),

              const SizedBox(height: 22),

              const Icon(Icons.lightbulb_outline, size: 28, color: _gold),

              const SizedBox(height: 12),

              const Text(
                'How do you learn best?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _softWhite,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "We'll set up your questions this way.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: _softWhite.withValues(alpha: 0.5),
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 24),

              _option(
                style: StudyStyle.explanations,
                icon: Icons.help_outline,
                label: 'Answers and explanations',
                subtitle: 'Show me why I missed it',
              ),
              _option(
                style: StudyStyle.answersOnly,
                icon: Icons.check_circle_outline,
                label: 'Answers only',
                subtitle: 'Just show me the right one',
              ),
              _option(
                style: StudyStyle.quizFormat,
                icon: Icons.format_list_numbered,
                label: 'Quiz format',
                subtitle: 'Score me at the end',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
