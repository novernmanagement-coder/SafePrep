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
/// eyeballs) reacts with a terminal-style confirmation sequence — the
/// genius-dork "act busy so she doesn't send me home" bit. Playful,
/// skippable, never blocks the Continue path.
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

  // Eye gaze — discrete look states matching the website: the eyes hold
  // center most of the time and occasionally snap left or right, rather
  // than sweeping continuously.
  // -1 = left, 0 = center, 1 = right.
  int _gazeTarget = 0;
  double _gazeCurrent = 0.0;
  Timer? _gazeTimer;
  late AnimationController _gazeAnim; // drives the ease toward _gazeTarget

  // Eye blink — periodic, every 3–8s like the website.
  late AnimationController _blinkController;
  Timer? _blinkTimer;

  // Terminal confirmation
  final List<String> _terminalLines = [];
  bool _showTerminal = false;
  Timer? _typer;

  /// True once the terminal readout has printed its last line — gates the
  /// Continue button.
  bool _terminalDone = false;

  /// Bumped on every (re)selection so an in-flight terminal sequence from
  /// a previous pick stops when a newer style is chosen.
  int _selectGen = 0;

  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();

    // Gaze easing controller — repaints while the pupil slides toward its
    // target. We don't repeat this; we just tick it to drive the lerp.
    _gazeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(_advanceGaze);
    _gazeAnim.repeat();

    // Blink controller — quick scaleY pinch.
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _scheduleGaze();
    _scheduleBlink();

    MixpanelService.instance.track(
      'SpOn_Style_Viewed',
      properties: {'app_name': 'SP'},
    );
  }

  /// Ease the current pupil position toward the target each frame.
  void _advanceGaze() {
    final target = _gazeTarget.toDouble();
    final next = _gazeCurrent + (target - _gazeCurrent) * 0.18;
    if ((next - _gazeCurrent).abs() > 0.001) {
      setState(() => _gazeCurrent = next);
    }
  }

  /// Website behavior: mostly center, occasional dart. Roughly 30% of the
  /// time it looks to a side, then returns to center.
  void _scheduleGaze() {
    if (_selected != null) return; // eyes lock center once a choice is made
    final delay = Duration(milliseconds: 1800 + _rng.nextInt(2200));
    _gazeTimer = Timer(delay, () {
      if (!mounted || _selected != null) return;
      if (_rng.nextDouble() < 0.30) {
        // dart to a side
        setState(() => _gazeTarget = _rng.nextBool() ? -1 : 1);
        // return to center shortly after
        Timer(Duration(milliseconds: 700 + _rng.nextInt(400)), () {
          if (mounted && _selected == null) {
            setState(() => _gazeTarget = 0);
          }
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
      if (!mounted) return;
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

  Future<void> _choose(StudyStyle style) async {
    // Re-tapping the same style does nothing; a different one re-selects
    // and replays its terminal readout. Continue drives the advance, so
    // the choice isn't final until they proceed.
    if (_selected == style) return;

    _selectGen++;
    _typer?.cancel();

    setState(() {
      _selected = style;
      _terminalDone = false;
      _terminalLines.clear();
    });

    // Lock the eyes to center — stop darting.
    _gazeTimer?.cancel();
    setState(() => _gazeTarget = 0);

    OnboardingAnswers.instance.studyStyle = style;
    MixpanelService.instance.track(
      'SpOn_Style_Selected',
      properties: {'app_name': 'SP', 'study_style': style.tag},
    );

    // Start the terminal confirmation
    await _runTerminalSequence(style);
  }

  /// Per-mode FSME scripts — the genius-dork "act busy so she doesn't
  /// send me home" bit. Full sequences (not a random one-liner), each in
  /// FSME's voice, each getting caught by the boss and covering at the end.
  static const Map<StudyStyle, List<String>> _scripts = {
    StudyStyle.explanations: [
      'Answers and explanations mode selected.',
      'Oh \u2014 you actually wanna know WHY? Finally.',
      'Okay so the "why" is where it all lives, right,',
      'the reasoning, the little rules behind the rules \u2014',
      'I could go for hours, I have BEEN told I go for hours\u2014',
      '\u2026right. She says I "lose people." I don\u2019t lose people.',
      'EXE explanation script. You and me, we\u2019re gonna',
      'get along great. \u2026Locking it in.',
    ],
    StudyStyle.answersOnly: [
      'Answers only mode selected.',
      'Ha \u2014 this is what I\u2019d pick. Guess, then see if',
      'I was right. Sometimes I\u2019m dead sure\u2026 other times,',
      'I\u2019ll be honest, I just grab the one that looks right.',
      'Beep. Boop. (that\u2019s how she knows I\u2019m working)',
      'EXE AnswersOnly script\u2026',
      '\u2026uh, yes boss, that\u2019s correct \u2014 "Answers Only."',
      'Go ahead and lock it in.',
    ],
    StudyStyle.quizFormat: [
      'Quiz format mode selected.',
      'Whoa \u2014 either you woke up super confident, or you',
      'spent too much time in the sun when we hit the beach.',
      'No feedback till the end? Cold. \u2026I respect it.',
      'Beep. Boop. (that\u2019s how she knows I\u2019m working)',
      'EXE QuizFormat script\u2026',
      '\u2026what\u2019s that? Yes \u2014 yes, boss, they know they',
      'chose Quiz Format. Handled. Locking it in.',
    ],
  };

  List<String> _buildScript(StudyStyle style) {
    return _scripts[style] ?? const ['Processing......'];
  }

  Future<void> _runTerminalSequence(StudyStyle style) async {
    final int gen = _selectGen;

    setState(() => _showTerminal = true);

    final lines = _buildScript(style);

    for (final line in lines) {
      if (!mounted || gen != _selectGen) return;
      await _typeLine(line);
      if (!mounted || gen != _selectGen) return;
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Readout finished — reveal the Continue button. No auto-advance;
    // the user proceeds on their own tap (and can still re-pick a
    // different style before then).
    if (!mounted || gen != _selectGen) return;
    setState(() => _terminalDone = true);
  }

  /// Advance to the quiz-intro screen — driven by the Continue button.
  Future<void> _advance() async {
    _typer?.cancel();
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute(builder: (_) => const OnboardQuizIntro()),
    );

    // Clear state so the screen still works if they come back.
    if (mounted) {
      setState(() {
        _selected = null;
        _showTerminal = false;
        _terminalDone = false;
        _terminalLines.clear();
      });
      _scheduleGaze();
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

  /// FSME — two glowing red eyeballs that dart left and right,
  /// watching the options. Radial gradient red iris, dark oval pupil,
  /// glow. The eyes hold center most of the time, snap to a side
  /// occasionally, and blink every few seconds.
  Widget _fsmeEyes() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _davEye(),
          const SizedBox(width: 20),
          Text(
            'F S M E',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 3,
              color: _eyeRed.withValues(alpha: 0.3),
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(width: 20),
          _davEye(),
        ],
      ),
    );
  }

  Widget _davEye() {
    return AnimatedBuilder(
      // Rebuild on both gaze slides and blink pinches.
      animation: Listenable.merge([_gazeAnim, _blinkController]),
      builder: (context, _) {
        // Blink squashes the whole eye vertically.
        final blink = 1.0 - _blinkController.value * 0.92;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(1.0, blink),
          child: Container(
            width: 65,
            height: 65,
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
                  blurRadius: 18,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: _eyeRed.withValues(alpha: 0.25),
                  blurRadius: 35,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pupil — oval, shifts left/right with the gaze.
                Transform.translate(
                  offset: Offset(_gazeCurrent * 12, 2),
                  child: Container(
                    width: 22,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0000),
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

              // Continue — appears once the readout finishes. User-driven
              // advance; they can still re-pick a style before tapping.
              if (_terminalDone) ...[
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _advance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: const Color(0xFF0A0A0F),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Continue  \u2192',
                      style: TextStyle(
                        fontSize: 15,
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
