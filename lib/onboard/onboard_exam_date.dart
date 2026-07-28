import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../mixpanel_service.dart';
import 'onboard_answers.dart';
import 'onboard_study_style.dart';

/// Onboarding screen 2 of 5 — "When's your exam?"
///
/// Three urgency bands, no calendar. The band is the emotional signal we
/// act on: how anxious is this person, and therefore how hard does FSME
/// push.
///
///   1-2 days  → they NEED it now. Straight to the cram pitch, no peek.
///   3-4 days  → some room. Likely a shopper. FSME offers a sneak peek.
///   5+ days   → most room, most likely to wander off. Same peek hook.
///
/// The peek is a one-time bit: FSME, pretending the boss stepped out for
/// coffee, sneaks the user through three quick questions, then panics
/// ("she's coming back, act cool!") and vanishes. No purchase CTA — it's
/// pure goodwill, aimed at the shoppers who have time to hesitate.
///
/// Buttons map onto the existing ExamWindow enum so nothing downstream
/// changes; only the button labels and the FSME copy are rebanded:
///   oneToThree → 1-2 days
///   fourToTen  → 3-4 days
///   tenPlus    → 5+ days
/// (notScheduled stays in the enum but is no longer offered here.)
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
  static const Color _green = Color(0xFF639922);

  ExamWindow? _selected;

  /// One-time guard for the peek. Once FSME has run his bit, it never
  /// fires again this session.
  bool _peekUsed = false;

  // ── FSME reaction box ───────────────────────────────────────────────
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

  /// Clean band label per window, for the SP_exam_band_selected event.
  static String _bandTag(ExamWindow w) {
    switch (w) {
      case ExamWindow.oneToThree:
        return '1-2';
      case ExamWindow.fourToTen:
        return '3-4';
      case ExamWindow.tenPlus:
        return '5+';
      case ExamWindow.notScheduled:
        return 'not_scheduled';
    }
  }

  /// True for the two bands that get the sneak-peek offer.
  static bool _peekBand(ExamWindow w) =>
      w == ExamWindow.fourToTen || w == ExamWindow.tenPlus;

  /// Band-specific reaction lines, split for terminal-style display.
  static const Map<ExamWindow, List<String>> _reactions = {
    // 1-2 days — no time for games, straight cram pitch.
    ExamWindow.oneToThree: [
      'Ok so I bet you crammed for your',
      'history test the night before...',
      'but this time you have this app —',
      'designed just for you.',
      "Yup, that's right.",
      "I'll have you ready in less than 4 hours.",
    ],
    // 3-4 days — the "sleep 3 of them" / World History bit, then peek.
    ExamWindow.fourToTen: [
      'ha... 3+ days until the exam,',
      'with this app you can sleep for 3 of those days',
      '(you know just like world history in High School)',
      'My App is so good we can get you ready',
      'in less than 4 hours, plus, keep you',
      'in-tune with our 60 second trainers',
    ],
    // 5+ days — the relaxed "how do you wanna do this" bit, then peek.
    ExamWindow.tenPlus: [
      'Dude, how do you wanna do this?',
      'I get you ready in 4 hours, you use the',
      '60-second trainers to keep it fresh',
      'up until exam day...',
      'or we hit the beach, kick back,',
      'and wait till the day before.',
      "Either way, I'm cool.",
      'This app adapts to whatever you want.',
      "(don't tell the boss — I can guarantee",
      'without a doubt that you will 100%',
      'more than likely pass the exam)',
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

    // Existing event — unchanged tag, keeps downstream analytics intact.
    MixpanelService.instance.track(
      'onboarding_exam_date_selected',
      properties: {'app_name': 'SP', 'exam_window': window.tag},
    );
    // New clean band event for the urgency funnel.
    MixpanelService.instance.track(
      'SP_exam_band_selected',
      properties: {'app_name': 'SP', 'band': _bandTag(window)},
    );

    await _runFsme(window);
  }

  /// FSME reaction: box appears, prints its lines one at a time. On the
  /// two peek bands it ends by offering the sneak peek; otherwise it just
  /// shows the Next button.
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

    if (mounted) {
      setState(() {
        _selected = null;
        _fsmeActive = false;
        _fsmeLines.clear();
      });
    }
  }

  // ── PEEK ────────────────────────────────────────────────────────────

  /// Modal 1: FSME offers the sneak peek. No timer — waits for Yes/No.
  Future<void> _offerPeek() async {
    if (_peekUsed) {
      // Already used this session — just move on.
      _advance();
      return;
    }

    MixpanelService.instance.track(
      'SP_peek_offered',
      properties: {
        'app_name': 'SP',
        'band': _selected != null ? _bandTag(_selected!) : 'unknown',
      },
    );

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => _PeekOfferDialog(gold: _gold, eyeRed: _eyeRed),
    );

    if (!mounted) return;

    if (accepted == true) {
      MixpanelService.instance.track(
        'SP_peek_watched',
        properties: {'app_name': 'SP'},
      );
      _peekUsed = true;
      await _runPeek();
    } else {
      MixpanelService.instance.track(
        'SP_peek_declined',
        properties: {'app_name': 'SP'},
      );
      _peekUsed = true;
      // No thanks — straight on.
    }

    if (mounted) _advance();
  }

  /// Modal 2 + 3: the hands-off question run, then the "act cool" exit.
  Future<void> _runPeek() async {
    // Modal 2 — three questions, self-advancing. Returns when the last
    // answer has shown and the 3-second hold has elapsed.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (_) => _PeekQuestionsDialog(
        questions: _peekQuestions,
        gold: _gold,
        green: _green,
        eyeRed: _eyeRed,
        softWhite: _softWhite,
      ),
    );

    if (!mounted) return;

    // Modal 3 — "boss is coming, act cool", 3-second hold, then closes.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (_) => _PeekExitDialog(gold: _gold, eyeRed: _eyeRed),
    );
  }

  /// Three fixed ServSafe questions for the peek. Swap freely.
  static const List<_PeekQ> _peekQuestions = [
    _PeekQ(
      question:
          'What is the minimum internal cooking temperature for '
          'poultry?',
      options: ['145°F (63°C)', '155°F (68°C)', '165°F (74°C)', '135°F (57°C)'],
      correctIndex: 2,
    ),
    _PeekQ(
      question: 'What is the temperature danger zone for TCS foods?',
      options: ['32°F – 100°F', '41°F – 135°F', '50°F – 120°F', '41°F – 165°F'],
      correctIndex: 1,
    ),
    _PeekQ(
      question:
          'How long may hot TCS food be held without temperature '
          'control before it must be discarded?',
      options: ['2 hours', '4 hours', '6 hours', '8 hours'],
      correctIndex: 1,
    ),
  ];

  // ── UI ──────────────────────────────────────────────────────────────

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

  /// One tappable band row.
  Widget _option(ExamWindow window, String label) {
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
                color: isSelected ? _gold : _gold.withValues(alpha: 0.3),
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
                      fontWeight: FontWeight.w600,
                      color: _softWhite,
                    ),
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

  /// FSME reaction box — animated eyes + terminal readout + button.
  /// The button is "Next" normally, or "Continue" on peek bands (which
  /// launches the peek before advancing).
  Widget _fsmeBox() {
    final bool isPeek =
        _selected != null && _peekBand(_selected!) && !_peekUsed;

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
              onPressed: isPeek ? _offerPeek : _advance,
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _darkBg,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                isPeek ? 'Continue  \u2192' : 'Next  \u2192',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
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

              _option(ExamWindow.oneToThree, '1\u20132 days'),
              _option(ExamWindow.fourToTen, '3\u20134 days'),
              _option(ExamWindow.tenPlus, '5+ days'),

              if (_fsmeActive) _fsmeBox(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single peek question.
class _PeekQ {
  final String question;
  final List<String> options;
  final int correctIndex;
  const _PeekQ({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}

// ── PEEK MODAL 1: the offer ───────────────────────────────────────────
class _PeekOfferDialog extends StatelessWidget {
  final Color gold;
  final Color eyeRed;
  const _PeekOfferDialog({required this.gold, required this.eyeRed});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0A0E14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: gold.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StaticEyes(eyeRed: eyeRed),
            const SizedBox(height: 18),
            for (final line in const [
              'Psst. Hey.',
              'The boss is getting a coffee.',
              'Wanna see the 60 Second Refresher',
              'before she gets back?',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '> $line',
                  style: TextStyle(
                    fontFamily: 'Menlo',
                    fontFamilyFallback: const ['Courier', 'monospace'],
                    fontSize: 12.5,
                    height: 1.4,
                    color: gold,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: gold.withValues(alpha: 0.7),
                      side: BorderSide(color: gold.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('No thanks'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: const Color(0xFF0A0A0F),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Yes, show me',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── PEEK MODAL 2: the three questions (hands-off) ─────────────────────
class _PeekQuestionsDialog extends StatefulWidget {
  final List<_PeekQ> questions;
  final Color gold;
  final Color green;
  final Color eyeRed;
  final Color softWhite;
  const _PeekQuestionsDialog({
    required this.questions,
    required this.gold,
    required this.green,
    required this.eyeRed,
    required this.softWhite,
  });

  @override
  State<_PeekQuestionsDialog> createState() => _PeekQuestionsDialogState();
}

class _PeekQuestionsDialogState extends State<_PeekQuestionsDialog> {
  int _index = 0;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  /// Hands-off: show question ~1.6s, reveal the answer, hold ~2s, advance.
  /// After the last question's answer shows, hold 3s then close.
  Future<void> _run() async {
    for (var i = 0; i < widget.questions.length; i++) {
      if (!mounted) return;
      setState(() {
        _index = i;
        _revealed = false;
      });
      await Future.delayed(const Duration(milliseconds: 1600));
      if (!mounted) return;
      setState(() => _revealed = true);

      final isLast = i == widget.questions.length - 1;
      // Last answer holds 3s (spec); others hold ~2s before advancing.
      await Future.delayed(Duration(milliseconds: isLast ? 3000 : 2000));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_index];

    return Dialog(
      backgroundColor: const Color(0xFF0A0E14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: widget.gold.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '60 SECOND REFRESHER',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: widget.gold.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  '${_index + 1} / ${widget.questions.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Menlo',
                    color: widget.softWhite.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              q.question,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: widget.softWhite,
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < q.options.length; i++) _optionRow(q, i),
          ],
        ),
      ),
    );
  }

  Widget _optionRow(_PeekQ q, int i) {
    final bool isCorrect = i == q.correctIndex;
    final bool showGreen = _revealed && isCorrect;

    Color border = widget.gold.withValues(alpha: 0.25);
    Color fill = const Color(0xFF13130F);
    Color text = widget.softWhite.withValues(alpha: 0.85);

    if (showGreen) {
      border = widget.green;
      fill = widget.green.withValues(alpha: 0.15);
      text = const Color(0xFFC0DD97);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 13),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: showGreen ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              q.options[i],
              style: TextStyle(
                fontSize: 13.5,
                color: text,
                fontWeight: showGreen ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (showGreen) Icon(Icons.check, size: 16, color: widget.green),
        ],
      ),
    );
  }
}

// ── PEEK MODAL 3: the "act cool" exit ─────────────────────────────────
class _PeekExitDialog extends StatefulWidget {
  final Color gold;
  final Color eyeRed;
  const _PeekExitDialog({required this.gold, required this.eyeRed});

  @override
  State<_PeekExitDialog> createState() => _PeekExitDialogState();
}

class _PeekExitDialogState extends State<_PeekExitDialog> {
  @override
  void initState() {
    super.initState();
    // Hold 3 seconds, then close automatically.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0A0E14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: widget.gold.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StaticEyes(eyeRed: widget.eyeRed),
            const SizedBox(height: 18),
            for (final line in const [
              'Wait — she\'s coming back!',
              'Act cool. ACT COOL.',
              '...',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '> $line',
                  style: TextStyle(
                    fontFamily: 'Menlo',
                    fontFamilyFallback: const ['Courier', 'monospace'],
                    fontSize: 13,
                    height: 1.4,
                    color: widget.gold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Two static glowing eyes for the peek dialogs (no darting/blink — the
/// dialogs are short-lived).
class _StaticEyes extends StatelessWidget {
  final Color eyeRed;
  const _StaticEyes({required this.eyeRed});

  Widget _eye() {
    return Container(
      width: 40,
      height: 40,
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
            color: eyeRed.withValues(alpha: 0.6),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 13,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0000),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _eye(),
        const SizedBox(width: 14),
        Text(
          'F S M E',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 3,
            color: eyeRed.withValues(alpha: 0.3),
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(width: 14),
        _eye(),
      ],
    );
  }
}
