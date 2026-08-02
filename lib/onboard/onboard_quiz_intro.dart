import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants.dart';
import '../mixpanel_service.dart';
import 'onboard_answers.dart';
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
///
/// Below the CTA sits the FSME command box — two glowing red eyeballs that
/// dart and blink, then a terminal readout. FSME hypes up the "reward"
/// (the wildest thing he can offer is upsizing a fast-food combo), then
/// hands off to the confidence legend as "the technical stuff I'm supposed
/// to tell you." The confirmation line reflects the mode the user actually
/// chose on the study-style screen, not a hard-coded "Quiz mode."
///
/// Per the standing typing rule: user-audience lines type out character
/// by character; boss/self/processing lines reveal instantly, one line
/// at a time.
class OnboardQuizIntro extends StatefulWidget {
  const OnboardQuizIntro({super.key});

  @override
  State<OnboardQuizIntro> createState() => _OnboardQuizIntroState();
}

/// Who a terminal line is directed at / how it renders. Matches the
/// system used on the intro, exam-date, and study-style screens.
/// - user: FSME's default voice (gold) — types out.
/// - boss: directed at the boss (blue) — instant.
/// - self: muttering/thinking to himself (gray) — instant.
/// - processing: system-status bits (Beep Boop, "X confirmed") — teal,
///   instant.
/// [flash] marks the "sudden real expertise" beat — bold gold.
enum _FsmeAudience { user, boss, self, processing }

/// Script-definition line (immutable).
class _FsmeLine {
  final String text;
  final _FsmeAudience audience;
  final bool flash;
  final bool indent;
  const _FsmeLine(
    this.text, {
    this.audience = _FsmeAudience.user,
    this.flash = false,
    this.indent = false,
  });
}

/// Mutable render-time counterpart — [text] grows as a user-audience
/// line types out; other lines just get their full text set once.
class _TermLine {
  String text;
  final _FsmeAudience audience;
  final bool flash;
  final bool indent;
  _TermLine(
    this.text, {
    this.audience = _FsmeAudience.user,
    this.flash = false,
    this.indent = false,
  });
}

class _OnboardQuizIntroState extends State<OnboardQuizIntro>
    with TickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _eyeRed = Color(0xFFE24B4A);
  // Matches the boss-line / self-line / processing colors used on the
  // intro, exam-date, and study-style screens.
  static const Color _bossBlue = Color(0xFF4A9BE2);
  static const Color _selfGray = Color(0xFF9E9E9E);
  static const Color _processingTeal = Color(0xFF6FA8A6);

  bool _starting = false;

  /// Lines revealed so far — populated by [_revealScript].
  final List<_TermLine> _revealedLines = [];

  /// The mode the user picked on the study-style screen, so FSME's
  /// confirmation line matches ("Answers only confirmed", etc.) instead
  /// of always claiming "Quiz mode."
  String get _modeLabel {
    switch (OnboardingAnswers.instance.studyStyle) {
      case StudyStyle.explanations:
        return 'Answers and explanations';
      case StudyStyle.answersOnly:
        return 'Answers only';
      case StudyStyle.quizFormat:
        return 'Quiz format';
      case null:
        return 'Study mode';
    }
  }

  /// FSME's script for this screen. Built as a getter (not a static
  /// const) since the first line depends on `_modeLabel`.
  List<_FsmeLine> get _script => [
    _FsmeLine('$_modeLabel confirmed.', audience: _FsmeAudience.processing),
    _FsmeLine('Ok my friend, let\u2019s knock this next bit out.'),
    _FsmeLine(
      '10 questions, then we get crazy. Maybe this time, wait for it\u2026',
    ),
    _FsmeLine('we order a large combo. You heard right \u2014 I said LARGE.'),
    _FsmeLine('Beep, braang, beep.', audience: _FsmeAudience.processing),
    _FsmeLine('Hey \u2014 I didn\u2019t do that. Boss must be getting ready.'),
    _FsmeLine('Ok, let\u2019s do this. Here\u2019s how this works:'),
    _FsmeLine('I give you one question at a time. You select an answer \u2014'),
    _FsmeLine('as soon as you select, it\u2019s locked in.'),
    _FsmeLine('Then, this is the important part: you tell us your confidence'),
    _FsmeLine('level for the answer you selected. Here\u2019s my scale:'),
    _FsmeLine('1 star = I guessed, not confident at all', indent: true),
    _FsmeLine(
      '2 star = I guessed, but it\u2019s an educated guess',
      indent: true,
    ),
    _FsmeLine(
      '3 star = I think I know the answer, but I could be wrong',
      indent: true,
    ),
    _FsmeLine('4 star = I know this, I\u2019m 95% sure', indent: true),
    _FsmeLine('5 star = 100% I know this is the correct answer', indent: true),
  ];

  // Eye gaze — discrete look states matching the website: the eyes hold
  // center most of the time and occasionally snap left or right.
  // -1 = left, 0 = center, 1 = right.
  int _gazeTarget = 0;
  double _gazeCurrent = 0.0;
  Timer? _gazeTimer;
  late AnimationController _gazeAnim;

  // Eye blink — periodic, every 3–8s.
  late AnimationController _blinkController;
  Timer? _blinkTimer;

  final math.Random _rng = math.Random();

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

    _scheduleGaze();
    _scheduleBlink();

    MixpanelService.instance.track(
      'SpOn_QIntro_Viewed',
      properties: {'app_name': 'SP'},
    );

    _revealScript();
  }

  /// Reveals the script one line at a time. User-audience lines type
  /// out character by character; boss/self/processing lines appear
  /// instantly. Small pause between every line either way.
  Future<void> _revealScript() async {
    for (final line in _script) {
      if (!mounted) return;

      if (line.audience == _FsmeAudience.user) {
        final entry = _TermLine(
          '',
          audience: line.audience,
          flash: line.flash,
          indent: line.indent,
        );
        setState(() => _revealedLines.add(entry));
        for (var i = 1; i <= line.text.length; i++) {
          if (!mounted) return;
          setState(() => entry.text = line.text.substring(0, i));
          await Future.delayed(const Duration(milliseconds: 18));
        }
      } else {
        setState(
          () => _revealedLines.add(
            _TermLine(
              line.text,
              audience: line.audience,
              flash: line.flash,
              indent: line.indent,
            ),
          ),
        );
      }

      await Future.delayed(const Duration(milliseconds: 400));
    }
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
      if (!mounted) return;
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
    super.dispose();
  }

  Future<void> _startQuiz() async {
    if (_starting) return;
    setState(() => _starting = true);

    MixpanelService.instance.track(
      'SpOn_Diag_Viewed',
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

  /// One glowing red eyeball that darts and blinks — same construction as
  /// the study-style screen, resized to match the intro/exam-date/
  /// study-style spec (26x26, 8x10 pupil).
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

  /// One line in the terminal readout. Color follows [line.audience];
  /// [line.flash] bolds it; [line.indent] nudges confidence sub-lines in
  /// from the left and drops the "> " prefix.
  Widget _terminalLine(_TermLine line) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6, left: line.indent ? 16 : 0),
      child: Text(
        line.indent ? line.text : '> ${line.text}',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          height: 1.5,
          fontWeight: line.flash ? FontWeight.bold : FontWeight.normal,
          color: switch (line.audience) {
            _FsmeAudience.boss => _bossBlue,
            _FsmeAudience.self => _selfGray,
            _FsmeAudience.processing => _processingTeal,
            _FsmeAudience.user => _gold.withValues(alpha: 0.8),
          },
        ),
      ),
    );
  }

  /// FSME command box — animated eyes + label, then the terminal readout.
  /// FSME hypes the "reward" (a large combo — the wildest thing he can
  /// offer), then hands off to the confidence legend as the technical bit.
  Widget _fsmeBox() {
    return Column(
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
            border: Border.all(color: _gold.withValues(alpha: 0.25), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [for (final line in _revealedLines) _terminalLine(line)],
          ),
        ),
      ],
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

              const SizedBox(height: 26),

              // ── FSME command box ──────────────────────────────────
              _fsmeBox(),
            ],
          ),
        ),
      ),
    );
  }
}
