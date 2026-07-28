import 'dart:async';
import 'dart:math' as math;
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
///
/// Below the CTA sits the FSME command box — two glowing red eyeballs that
/// dart and blink, then a terminal readout confirming Quiz mode and
/// spelling out how confidence rating works. Same dark-terminal + gold-mono
/// aesthetic as the study-style screen, so the character reads as one
/// continuous presence across the funnel.
class OnboardQuizIntro extends StatefulWidget {
  const OnboardQuizIntro({super.key});

  @override
  State<OnboardQuizIntro> createState() => _OnboardQuizIntroState();
}

class _OnboardQuizIntroState extends State<OnboardQuizIntro>
    with TickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _eyeRed = Color(0xFFE24B4A);

  bool _starting = false;

  /// One snark line, chosen once when the screen builds so it stays
  /// stable across rebuilds.
  late final String _snark;

  static const List<String> _quizSnark = [
    'No peeking. The answers are locked in a vault......',
    'Quiz mode? Brave. Very brave......',
    'Someone woke up feeling confident today......',
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
    _snark = _quizSnark[_rng.nextInt(_quizSnark.length)];

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
  /// the study-style screen.
  Widget _davEye() {
    return AnimatedBuilder(
      animation: Listenable.merge([_gazeAnim, _blinkController]),
      builder: (context, _) {
        final blink = 1.0 - _blinkController.value * 0.92;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(1.0, blink),
          child: Container(
            width: 44,
            height: 44,
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
                  blurRadius: 14,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: _eyeRed.withValues(alpha: 0.25),
                  blurRadius: 26,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: Center(
              child: Transform.translate(
                offset: Offset(_gazeCurrent * 8, 1),
                child: Container(
                  width: 14,
                  height: 17,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0000),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// One line in the terminal readout. [indent] nudges the confidence
  /// sub-lines in from the left and drops the "> " prefix.
  Widget _terminalLine(String text, {bool indent = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6, left: indent ? 16 : 0),
      child: Text(
        indent ? text : '> $text',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          height: 1.5,
          color: _gold.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  /// FSME command box — animated eyes + label, then the terminal readout.
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
            children: [
              _terminalLine('Quiz mode confirmed'),
              _terminalLine(_snark),
              _terminalLine('One question at a time — one selection each'),
              _terminalLine('Then rate your confidence:'),
              _terminalLine('1 = basically a guess', indent: true),
              _terminalLine(
                '2 = low confidence, but it feels at least close',
                indent: true,
              ),
              _terminalLine(
                "3 = eliminate the obvious, expect you're right",
                indent: true,
              ),
              _terminalLine(
                '4 = you know it\'s right, very little hesitation',
                indent: true,
              ),
              _terminalLine(
                '5 = no hesitation — your answer IS correct',
                indent: true,
              ),
            ],
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
