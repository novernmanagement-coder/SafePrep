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
///
/// FSME appears on page LOAD now (not gated on selection) with an intro
/// grumble line, then the band-specific reaction script appends below
/// it once a timeframe is picked.
class OnboardExamDate extends StatefulWidget {
  const OnboardExamDate({super.key});

  @override
  State<OnboardExamDate> createState() => _OnboardExamDateState();
}

/// Who a reaction line is directed at / how it should render.
/// - user: FSME's default voice (gold) — types out character by
///   character, per the standing typing rule.
/// - boss: directed at the boss (blue) — appears instantly.
/// - self: muttering/thinking to himself (gray) — appears instantly.
/// [flash] marks the "sudden real expertise" beat — bold gold,
/// independent of audience (it's still addressed to the user, just
/// rendered with emphasis).
enum _FsmeAudience { user, boss, self, processing }

/// Script-definition line (immutable).
class _FsmeLine {
  final String text;
  final _FsmeAudience audience;
  final bool flash;
  const _FsmeLine(
    this.text, {
    this.audience = _FsmeAudience.user,
    this.flash = false,
  });
}

/// Mutable render-time counterpart — [text] grows as a user-audience
/// line types out; boss/self lines just get their full text set once.
class _RenderLine {
  String text;
  final _FsmeAudience audience;
  final bool flash;
  _RenderLine(this.text, this.audience, {this.flash = false});
}

class _OnboardExamDateState extends State<OnboardExamDate>
    with TickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _eyeRed = Color(0xFFE24B4A);
  // Matches the Boss's eye color / the intro page's boss-line color.
  static const Color _bossBlue = Color(0xFF4A9BE2);
  // FSME talking/thinking to himself — grayed, matches the intro page.
  static const Color _selfGray = Color(0xFF9E9E9E);
  // FSME's "processing" system-status bits — teal, matches the rest of
  // the funnel.
  static const Color _processingTeal = Color(0xFF6FA8A6);

  ExamWindow? _selected;

  /// One-time guard for the peek. Once FSME has run his bit, it never
  /// fires again this session.
  bool _peekUsed = false;

  // ── FSME reaction box ───────────────────────────────────────────────
  /// True once the load-time intro reveal starts — gates the box's
  /// visibility. No longer tied to band selection.
  bool _fsmeActive = false;
  Timer? _introTimer;

  /// The load-time grumble line — shown once, never cleared/rebuilt.
  final List<_RenderLine> _introLines = [];

  /// Band-specific reaction lines — cleared and rebuilt on each
  /// (re)selection, rendered below [_introLines].
  final List<_RenderLine> _fsmeLines = [];

  /// Bumped on every band (re)selection. An in-flight reaction loop
  /// checks it and stops appending if a newer selection has started.
  int _fsmeGen = 0;

  int _gazeTarget = 0;
  double _gazeCurrent = 0.0;
  Timer? _gazeTimer;
  late AnimationController _gazeAnim;

  late AnimationController _blinkController;
  Timer? _blinkTimer;

  final math.Random _rng = math.Random();

  /// Keeps the newest FSME line in view as lines print in.
  final ScrollController _scroll = ScrollController();

  /// The load-time intro grumble — self-talk, before he ever addresses
  /// the user directly.
  static const String _introGrumble =
      "It's not enough I have to greet everyone, now she's making me "
      "collect information...";

  /// Full load-time intro script: grumble → processing → self-pity
  /// result. All self/processing audience, so all reveal instantly
  /// (no typing) with a pause between each.
  static const List<_FsmeLine> _introScript = [
    _FsmeLine(_introGrumble, audience: _FsmeAudience.self),
    _FsmeLine(
      'Running self-pity-party routine....',
      audience: _FsmeAudience.processing,
    ),
    _FsmeLine(
      'Results: "I should be the boss, I\'m smart, given time I could '
      'have made the ingenious adaptive study engine"',
      audience: _FsmeAudience.self,
    ),
  ];

  /// Clean band label per window (1/2/3), sent as the `band` property on
  /// SpOn_Date_Selected.
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
  /// FSME voice: genius dork — built the award-winning tools, can't say
  /// it smoothly, air-quotes the boss's jargon, grudging respect for her.
  ///
  /// Each opening grumble is tagged `self` (he's muttering before he
  /// catches himself addressing the user); the canonical "flash of real
  /// expertise" line per band is tagged `flash` (bold gold).
  static const Map<ExamWindow, List<_FsmeLine>> _reactions = {
    // 1-2 days — workload grumble + real reassurance.
    ExamWindow.oneToThree: [
      _FsmeLine(
        "It's not enough I have to greet everybody... now she wants "
        "me to be a data collector.",
        audience: _FsmeAudience.self,
      ),
      _FsmeLine('Ok, the boss wants me to record your exam date...'),
      _FsmeLine(
        '...ok, within two days, got it.',
        audience: _FsmeAudience.self,
      ),
      _FsmeLine('Ha, I bet this is what you did in high school \u2014'),
      _FsmeLine('crammed for the test the day before. I respect that.'),
      _FsmeLine('It\u2019s cool the boss wrote this super ingenious'),
      _FsmeLine(
        'adaptive study engine that\u2019ll have you ready in no time.',
      ),
      _FsmeLine(
        '...that\u2019s probably why she got the promotion.',
        audience: _FsmeAudience.self,
      ),
    ],
    // 3-4 days — the Byte-Me grievance + genuine confidence.
    ExamWindow.fourToTen: [
      _FsmeLine(
        "Here's what I don't get \u2014 I MADE the 60-second",
        audience: _FsmeAudience.self,
      ),
      _FsmeLine(
        'trainers, and somehow SHE gets the promotion.',
        audience: _FsmeAudience.self,
      ),
      _FsmeLine(
        'Okay fine, she built the "intuitive engine" and the',
        audience: _FsmeAudience.self,
      ),
      _FsmeLine(
        '"readiness algorithm"\u2026 but my six tools took first place.',
        audience: _FsmeAudience.self,
      ),
      _FsmeLine(
        'At the Byte-Me conference. Look it up.',
        audience: _FsmeAudience.self,
      ),
      _FsmeLine('3\u20134 days? Piece of cake.'),
      _FsmeLine('I\u2019ll have you ready in less than four hours...'),
      _FsmeLine('once you\u2019re exam-ready, use my award-winning'),
      _FsmeLine('60-second trainers \u2014 in case you didn\u2019t know,'),
      _FsmeLine('they took first place, beating out Goggles'),
      _FsmeLine('(Google\u2019s cousin) and their 12-hour trainers.'),
    ],
    // 5+ days — relaxed buddy energy + grudging respect for the boss.
    ExamWindow.tenPlus: [
      _FsmeLine("Dude, we got nothing but time. Here's what I think:"),
      _FsmeLine('We finish up this tour, Boss lady does her analysis'),
      _FsmeLine('thing, then we hit the beach, catch a movie \u2014'),
      _FsmeLine('whatever you like.'),
      _FsmeLine('The point is, her app prepares you like no other \u2014'),
      _FsmeLine("I'm telling you, less than four hours."),
      _FsmeLine('So\u2026 the beach, a movie? Let me know, dude.'),
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
      'SpOn_Date_Viewed',
      properties: {'app_name': 'SP'},
    );

    // FSME appears on load (not gated on selection) with the intro
    // script — self/processing lines, appear instantly, paced.
    _introTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _fsmeActive = true);
      _scheduleGaze();
      _scheduleBlink();
      _revealIntro();
    });
  }

  /// Reveals the load-time intro script one line at a time. Guarded by
  /// [_fsmeGen] so picking a band mid-reveal stops it (the selection
  /// then erases everything and starts the band script fresh).
  Future<void> _revealIntro() async {
    final int gen = _fsmeGen;
    for (final line in _introScript) {
      if (!mounted || gen != _fsmeGen) return;
      setState(
        () => _introLines.add(
          _RenderLine(line.text, line.audience, flash: line.flash),
        ),
      );
      _scrollToEnd();
      await Future.delayed(const Duration(milliseconds: 700));
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
    _introTimer?.cancel();
    _gazeAnim.dispose();
    _blinkController.dispose();
    _gazeTimer?.cancel();
    _blinkTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _choose(ExamWindow window) async {
    // Re-tapping the same band does nothing; tapping a different one
    // re-selects and replays that band's reaction. The Continue button
    // means the choice isn't final until they proceed, so there's no
    // reason to lock it.
    if (_selected == window) return;

    // Bump the generation so any in-flight reaction from a previous pick
    // stops appending lines.
    _fsmeGen++;

    setState(() {
      _selected = window;
      _peekUsed = false; // a new band selection re-arms the peek
    });

    OnboardingAnswers.instance.examWindow = window;

    // One selection event carrying both the raw window tag and the clean
    // band number (1/2/3) as properties — break down on `band` in
    // Mixpanel to see the urgency distribution.
    MixpanelService.instance.track(
      'SpOn_Date_Selected',
      properties: {
        'app_name': 'SP',
        'exam_window': window.tag,
        'band': _bandTag(window),
      },
    );

    await _runFsme(window);
  }

  /// FSME reaction: appends below the (already-showing) intro grumble,
  /// printing the band script one line at a time. User-audience lines
  /// type out character by character; boss/self lines appear instantly.
  /// On the two peek bands it ends by offering the sneak peek; otherwise
  /// it just shows the Next button.
  Future<void> _runFsme(ExamWindow window) async {
    final int gen = _fsmeGen;

    setState(() {
      _introLines.clear();
      _fsmeLines.clear();
    });

    final lines = _reactions[window] ?? const [_FsmeLine('Got it.')];

    await Future.delayed(const Duration(milliseconds: 450));
    for (final line in lines) {
      if (!mounted || gen != _fsmeGen) return;

      if (line.audience == _FsmeAudience.user) {
        final entry = _RenderLine('', line.audience, flash: line.flash);
        setState(() => _fsmeLines.add(entry));
        for (var i = 1; i <= line.text.length; i++) {
          if (!mounted || gen != _fsmeGen) return;
          setState(() => entry.text = line.text.substring(0, i));
          _scrollToEnd();
          await Future.delayed(const Duration(milliseconds: 18));
        }
      } else {
        setState(
          () => _fsmeLines.add(
            _RenderLine(line.text, line.audience, flash: line.flash),
          ),
        );
        _scrollToEnd();
      }

      await Future.delayed(const Duration(milliseconds: 700));
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Advance to the study-style screen — driven by the Next button.
  Future<void> _advance() async {
    final navigator = Navigator.of(context);

    await navigator.push(
      MaterialPageRoute(builder: (_) => OnboardStudyStyle()),
    );

    if (mounted) {
      setState(() {
        _selected = null;
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
      'SpOn_Date_PeekOffered',
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
        'SpOn_Date_PeekWatched',
        properties: {'app_name': 'SP'},
      );
      _peekUsed = true;
      await _runPeek();
    } else {
      MixpanelService.instance.track(
        'SpOn_Date_PeekDeclined',
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

  Widget _lineWidget(_RenderLine line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '> ${line.text}',
        style: TextStyle(
          fontFamily: 'Menlo',
          fontFamilyFallback: const ['Courier', 'monospace'],
          fontSize: 12,
          height: 1.5,
          fontWeight: line.flash ? FontWeight.bold : FontWeight.normal,
          color: switch (line.audience) {
            _FsmeAudience.boss => _bossBlue,
            _FsmeAudience.self => _selfGray,
            _FsmeAudience.processing => _processingTeal,
            _FsmeAudience.user => _gold,
          },
        ),
      ),
    );
  }

  /// FSME reaction box — animated eyes + terminal readout + button.
  /// Shows on page load (intro grumble); the band script appends below
  /// once a timeframe is picked. The Next/Continue button only appears
  /// once a band is actually selected.
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
                for (final line in _introLines) _lineWidget(line),
                for (final line in _fsmeLines) _lineWidget(line),
              ],
            ),
          ),
          if (_selected != null) ...[
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
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'No thanks',
                      maxLines: 1,
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: const Color(0xFF0A0A0F),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      minimumSize: const Size(0, 40),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Yes, show me',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
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
  final Color softWhite;
  const _PeekQuestionsDialog({
    required this.questions,
    required this.gold,
    required this.softWhite,
  });

  @override
  State<_PeekQuestionsDialog> createState() => _PeekQuestionsDialogState();
}

class _PeekQuestionsDialogState extends State<_PeekQuestionsDialog> {
  int _index = 0;
  bool _showAnswer = false;
  double _timerProgress = 0.0;

  /// Category color for the question bubble, matching the real
  /// 60-Second Refresh tool. All peek questions are Time & Temperature.
  static const Color _catColor = Color(0xFFC0392B);

  /// Answer bubble green, matching the real tool.
  static const Color _answerGreen = Color(0xFF3BA776);

  static const int _questionMs = 3000;
  static const int _answerMs = 2000;

  @override
  void initState() {
    super.initState();
    _run();
  }

  /// Hands-off burst: show question (timer fills), reveal answer (timer
  /// fills again), advance. Mirrors the real tool's question → answer
  /// flow. After the last answer, hold briefly then close.
  Future<void> _run() async {
    for (var i = 0; i < widget.questions.length; i++) {
      if (!mounted) return;
      setState(() {
        _index = i;
        _showAnswer = false;
        _timerProgress = 0.0;
      });

      await _animateTimer(_questionMs);
      if (!mounted) return;
      setState(() => _showAnswer = true);

      await _animateTimer(_answerMs);
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _animateTimer(int totalMs) async {
    final steps = totalMs ~/ 50;
    for (var s = 0; s <= steps; s++) {
      if (!mounted) return;
      setState(() => _timerProgress = s / steps);
      await Future.delayed(const Duration(milliseconds: 50));
    }
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
            const SizedBox(height: 16),

            // Question bubble — category color, white bold italic.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _catColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                q.question,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                  height: 1.35,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Answer bubble — green, fades in after the question holds.
            AnimatedOpacity(
              opacity: _showAnswer ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _answerGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  q.options[q.correctIndex],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Timer bar.
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: _timerProgress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _catColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
