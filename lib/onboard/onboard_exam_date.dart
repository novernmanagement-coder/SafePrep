import 'package:flutter/material.dart';
import '../mixpanel_service.dart';
import 'onboard_answers.dart';
import 'onboard_study_style.dart';

/// Onboarding screen 2 of 5 — "When's your exam?"
///
/// One tap, no confirm button. A small commitment that warms the user up
/// before the 10-question diagnostic, and the answer shapes every screen
/// after it.
class OnboardExamDate extends StatefulWidget {
  const OnboardExamDate({super.key});

  @override
  State<OnboardExamDate> createState() => _OnboardExamDateState();
}

class _OnboardExamDateState extends State<OnboardExamDate> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);

  ExamWindow? _selected;

  @override
  void initState() {
    super.initState();
    MixpanelService.instance.track(
      'onboarding_exam_date_viewed',
      properties: {'app_name': 'SP'},
    );
  }

  Future<void> _choose(ExamWindow window) async {
    if (_selected != null) return; // ignore double taps mid-transition

    setState(() => _selected = window);

    OnboardingAnswers.instance.examWindow = window;
    MixpanelService.instance.track(
      'onboarding_exam_date_selected',
      properties: {'app_name': 'SP', 'exam_window': window.tag},
    );

    // Captured before the await so the analyzer doesn't flag using
    // context across an async gap.
    final navigator = Navigator.of(context);

    // Brief pause so the tap registers visually before moving on.
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;

    await navigator.push(
      MaterialPageRoute(builder: (_) => OnboardStudyStyle()),
    );

    // Clear the guard so the screen still works if they come back.
    if (mounted) setState(() => _selected = null);
  }

  /// Progress indicator — 5 segments, [filled] of them gold.
  Widget _progress(int filled) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        return Container(
          width: 22,
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            color: i < filled ? _gold : _softWhite.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  /// One tappable answer row.
  ///
  /// [muted] styles the "Not scheduled yet" option a shade quieter — a
  /// real option, just not one the funnel is steering toward.
  Widget _option(ExamWindow window, String label, {bool muted = false}) {
    final bool isSelected = _selected == window;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _choose(window),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected ? _gold.withValues(alpha: 0.12) : _cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? _gold
                    : muted
                    ? _softWhite.withValues(alpha: 0.12)
                    : _gold.withValues(alpha: 0.3),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
                      color: muted
                          ? _softWhite.withValues(alpha: 0.7)
                          : _softWhite,
                    ),
                  ),
                ),
                Icon(
                  isSelected ? Icons.check : Icons.chevron_right,
                  size: 18,
                  color: isSelected
                      ? _gold
                      : muted
                      ? _softWhite.withValues(alpha: 0.3)
                      : _gold.withValues(alpha: 0.6),
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
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _progress(2),

              const SizedBox(height: 26),

              const Icon(Icons.event_outlined, size: 28, color: _gold),

              const SizedBox(height: 12),

              const Text(
                "When's your exam?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _softWhite,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'So we can optimize your plan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: _softWhite.withValues(alpha: 0.5),
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 26),

              _option(ExamWindow.oneToThree, '1\u20133 days'),
              _option(ExamWindow.fourToTen, '4\u201310 days'),
              _option(ExamWindow.tenPlus, '10+ days'),
              _option(
                ExamWindow.notScheduled,
                'Not scheduled yet',
                muted: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
