import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../mixpanel_service.dart';
import 'onboard_answers.dart';
import 'onboard_study_style.dart';

/// Onboarding screen 2 of 5 — "When's your exam?"
///
/// One tap, no confirm button. A small commitment that warms the user up
/// before the 10-question diagnostic, and the answer shapes every screen
/// after it.
///
/// After the tap, FSME (animated red eyeballs + terminal box) reacts to
/// the chosen window with a short, window-specific message, holds a few
/// seconds, then auto-advances to the study-style screen. Same character
/// treatment as the diagnostic so he reads as one continuous presence
/// across the funnel.
class OnboardExamDate extends StatefulWidget {
  const OnboardExamDate({super.key});

  @override
  State<OnboardExamDate> createState() => _OnboardExamDateState();
}

class _OnboardExamDateState extends State<OnboardExamDate>
    with TickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _eyeRed = Color(0xFFE24B4A);

  ExamWindow? _selected;

  // ── FSME ────────────────────────────────────────────────────────────
  bool _fsmeActive = false;
  final List<String> _fsmeLines = [];

  int _gazeTarget = 0;
  double _gazeCurrent = 0.0;
  Timer? _gazeTimer;
  late AnimationController _gazeAnim;

  late AnimationController _blinkController;
  Timer? _blinkTimer;

  final math.Random _rng = math.Random();

  /// Keeps the newest FSME line in view as lines print in.
  final ScrollController _scroll = ScrollController();

  /// Window-specific reaction lines, split for terminal-style display.
  static const Map<ExamWindow, List<String>> _reactions = {
    ExamWindow.oneToThree: [
      'Eyes off the screen —',
      'we need to prep you in a hurry.',
    ],
    ExamWindow.fourToTen: [
      "We've got some time.",
      "You'll still be ready in under 4 hours.",
      'Lean on the 60-second trainers to stay',
      'sharp right up to exam day.',
    ],
    ExamWindow.tenPlus: [
      'Plenty of runway.',
      "We'll get you fully prepared,",
      'one category at a time.',
      'The 60-second trainers keep you there.',
    ],
    ExamWindow.notScheduled: [
      "It's cool, I didn't have a date to the prom.",
      'I went by myself....',
      'wait, wait, wait...',
      "You were telling me you don't have a date",
      'for the EXAM.',
      'I thought we were connecting there for a moment.',
      '(how embarrassing)',
      'Running student brain-wash routine....',
      "Good, you don't recall my dateless prom.",
      "We'll get you prepped faster than",
      'I can figure out time-travel.',
    ],
  };

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

    MixpanelService.instance.track(
      'onboarding_exam_date_viewed',
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
      if (!mounted || !_fsmeActive) return;
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
      if (!mounted || !_fsmeActive) return;
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
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _choose(ExamWindow window) async {
    if (_selected != null) return; // ignore double taps mid-transition

    setState(() => _selected = window);

    OnboardingAnswers.instance.examWindow = window;
    MixpanelService.instance.track(
      'onboarding_exam_date_selected',
      properties: {'app_name': 'SP', 'exam_window': window.tag},
    );

    await _runFsme(window);
  }

  /// FSME reaction: box appears (with a Next button), then prints its
  /// lines one at a time. Advance is user-driven via [_advance] — no
  /// auto-advance.
  Future<void> _runFsme(ExamWindow window) async {
    setState(() {
      _fsmeActive = true;
      _fsmeLines.clear();
    });
    _scheduleGaze();
    _scheduleBlink();

    final lines = _reactions[window] ?? const ['Got it.'];

    await Future.delayed(const Duration(milliseconds: 450));
    for (final line in lines) {
      if (!mounted) return;
      setState(() => _fsmeLines.add(line));
      // Let the new line lay out, then bring it into view.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
      await Future.delayed(const Duration(milliseconds: 700));
    }
  }

  /// Advance to the study-style screen — driven by the Next button.
  Future<void> _advance() async {
    final navigator = Navigator.of(context);

    _fsmeActive = false;
    await navigator.push(
      MaterialPageRoute(builder: (_) => OnboardStudyStyle()),
    );

    // Clear the guard so the screen still works if they come back.
    if (mounted) {
      setState(() {
        _selected = null;
        _fsmeActive = false;
        _fsmeLines.clear();
      });
    }
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

  /// One glowing red eyeball that darts and blinks.
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

  /// FSME reaction box — animated eyes + terminal readout.
  Widget _fsmeBox() {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
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
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _gold.withValues(alpha: 0.4), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final line in _fsmeLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '> $line',
                      style: TextStyle(
                        fontFamily: 'Menlo',
                        fontFamilyFallback: const ['Courier', 'monospace'],
                        fontSize: 12,
                        height: 1.5,
                        color: _gold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Next  \u2192',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
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
          controller: _scroll,
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

              // FSME reaction — appears after a window is tapped.
              if (_fsmeActive) _fsmeBox(),
            ],
          ),
        ),
      ),
    );
  }
}
