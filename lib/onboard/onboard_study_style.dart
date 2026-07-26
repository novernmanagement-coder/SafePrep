import 'dart:async';
import 'dart:math' as math;
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
///
/// After the user picks a mode, the FSME character (two darting red
/// eyeballs) reacts with a terminal-style confirmation sequence that
/// types out what was selected. The character is a small personality
/// beat — it watches the options, then locks in the choice. Playful,
/// not distracting.
class OnboardStudyStyle extends StatefulWidget {
  const OnboardStudyStyle({super.key});

  @override
  State<OnboardStudyStyle> createState() => _OnboardStudyStyleState();
}

class _OnboardStudyStyleState extends State<OnboardStudyStyle>
    with TickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _eyeRed = Color(0xFFE24B4A);

  StudyStyle? _selected;

  // Eye animation
  late AnimationController _eyeController;
  late Animation<double> _eyePosition;

  // Terminal confirmation
  final List<String> _terminalLines = [];
  bool _showTerminal = false;
  Timer? _typer;

  @override
  void initState() {
    super.initState();

    _eyeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _eyePosition = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _eyeController, curve: Curves.easeInOut));

    MixpanelService.instance.track(
      'onboarding_study_style_viewed',
      properties: {'app_name': 'SP'},
    );
  }

  @override
  void dispose() {
    _eyeController.dispose();
    _typer?.cancel();
    super.dispose();
  }

  String _modeLabel(StudyStyle style) {
    switch (style) {
      case StudyStyle.explanations:
        return 'Answers and explanations';
      case StudyStyle.answersOnly:
        return 'Answers only';
      case StudyStyle.quizFormat:
        return 'Quiz format';
    }
  }

  String _modeTag(StudyStyle style) {
    switch (style) {
      case StudyStyle.explanations:
        return 'Explanation';
      case StudyStyle.answersOnly:
        return 'AnswersOnly';
      case StudyStyle.quizFormat:
        return 'QuizFormat';
    }
  }

  Future<void> _choose(StudyStyle style) async {
    if (_selected != null) return;

    setState(() => _selected = style);

    // Stop the eyes darting
    _eyeController.stop();

    OnboardingAnswers.instance.studyStyle = style;
    MixpanelService.instance.track(
      'onboarding_study_style_selected',
      properties: {'app_name': 'SP', 'study_style': style.tag},
    );

    // Start the terminal confirmation
    await _runTerminalSequence(style);
  }

  /// Per-mode snarky comments. One is picked at random each time.
  static const Map<StudyStyle, List<String>> _snark = {
    StudyStyle.explanations: [
      'I was sure they were going to select quiz mode......',
      'Explanations? Bold. Most people just guess and pray......',
      'Oh good, someone who actually wants to learn......',
      'Loading 20 years of instructor wisdom......',
    ],
    StudyStyle.answersOnly: [
      'Did I take the chili off the stove???......',
      'Straight to the point. I respect that......',
      'No hand-holding. I like your style......',
      'Fine, skip the lecture. See if I care......',
    ],
    StudyStyle.quizFormat: [
      "I'm not happy with Google right now, she owes me 300 bytes......",
      'Quiz mode? Brave. Very brave......',
      'No peeking. The answers are locked in a vault......',
      'Someone woke up feeling confident today......',
    ],
  };

  List<String> _buildScript(StudyStyle style) {
    final label = _modeLabel(style);
    final tag = _modeTag(style);
    final comments = _snark[style] ?? ['Processing......'];
    final comment = comments[math.Random().nextInt(comments.length)];

    return [
      '$label mode selected',
      comment,
      'User//: EXE $tag script',
      'User//: $tag mode locked in',
    ];
  }

  Future<void> _runTerminalSequence(StudyStyle style) async {
    setState(() => _showTerminal = true);

    final lines = _buildScript(style);

    for (final line in lines) {
      await _typeLine(line);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
    }

    // Brief pause, then navigate
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute(builder: (_) => const OnboardQuizIntro()),
    );

    // Clear the guard so the screen still works if they come back.
    if (mounted) {
      setState(() {
        _selected = null;
        _showTerminal = false;
        _terminalLines.clear();
      });
      _eyeController.repeat(reverse: true);
    }
  }

  Future<void> _typeLine(String text) async {
    final completer = Completer<void>();
    int charIndex = 0;

    setState(() {
      _terminalLines.add('');
    });

    _typer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      if (!mounted) {
        timer.cancel();
        completer.complete();
        return;
      }

      charIndex++;
      setState(() {
        _terminalLines[_terminalLines.length - 1] = text.substring(
          0,
          charIndex.clamp(0, text.length),
        );
      });

      if (charIndex >= text.length) {
        timer.cancel();
        completer.complete();
      }
    });

    return completer.future;
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

  /// The FSME character — two red eyeballs that dart back and forth,
  /// watching the options. Stops darting once a selection is made.
  Widget _fsmeEyes() {
    return AnimatedBuilder(
      animation: _eyePosition,
      builder: (context, _) {
        final offset = _selected != null ? 0.0 : _eyePosition.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _eyeball(offset),
              const SizedBox(width: 14),
              _eyeball(offset),
            ],
          ),
        );
      },
    );
  }

  Widget _eyeball(double offset) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: _darkBg,
        shape: BoxShape.circle,
        border: Border.all(color: _softWhite.withValues(alpha: 0.15), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(offset * 5, 0),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _eyeRed,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _eyeRed.withValues(alpha: 0.6),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0A0A0F),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Terminal confirmation box — types out the selection after the
  /// user picks a mode.
  Widget _terminalBox() {
    if (!_showTerminal) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: _showTerminal ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _gold.withValues(alpha: 0.25), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final line in _terminalLines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '> $line',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.5,
                    color: _gold.withValues(alpha: 0.8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// One tappable style option.
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

              // FSME character — darting eyes watching the options
              _fsmeEyes(),

              // Terminal confirmation — types out after selection
              _terminalBox(),
            ],
          ),
        ),
      ),
    );
  }
}
