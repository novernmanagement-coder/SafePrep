import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'constants.dart';
import 'csv_loader.dart';
import 'mixpanel_service.dart';
import 'iap_service.dart';
import 'category_study_page.dart';
import 'onboard/onboard_answers.dart';
import 'onboard/onboard_diagnostic_questions.dart';

/// Limited Rapid Fire — the $4.99 decline path's free taste.
///
/// This is a SELLING PAGE that happens to be a working tool. It runs a
/// capped version of Rapid Fire (3 weakest categories × 5 questions each
/// = 15 total) with a persistent "limited version" banner and a re-ask
/// at every category's 5-question ceiling. Each re-ask names the
/// category, states how many more questions are available, and offers
/// the unlock — turning one paywall into several conversion moments
/// that fire while the user is engaged.
///
/// VISUAL FIDELITY: mirrors the real RapidFirePage — the speech-bubble
/// question card ([_BubblePainter]), category color map, slide in/out,
/// and the ✓/✗/— score boxes — so the taste looks like the actual tool.
/// The interaction stays instant-answer (both choices shown at once, tap
/// reveals green/red) rather than the full tool's timed reveal, because
/// this is a funnel stage and snappier converts better.
///
/// Separate file from rapid_fire_page.dart intentionally. The full
/// trainer is a tool; this is a funnel stage that uses the tool's
/// mechanics. Mixing the two would compromise both.
class RapidFireLimitedPage extends StatefulWidget {
  const RapidFireLimitedPage({super.key});

  @override
  State<RapidFireLimitedPage> createState() => _RapidFireLimitedPageState();
}

class _RapidFireLimitedPageState extends State<RapidFireLimitedPage>
    with TickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _red = Color(0xFFC62828);

  static const int _questionsPerCategory = 5;
  static const int _slideInMs = 320;
  static const int _slideOutMs = 260;

  /// Category color map — matched to the real RapidFirePage so the
  /// speech bubble reads the same per category.
  static const Map<String, Color> _categoryColors = {
    'Time & Temperature': Color(0xFFC0392B),
    'Cross-Contamination': Color(0xFFE67E22),
    'Food Preparation': Color(0xFF27AE60),
    'Receiving & Storage': Color(0xFF2980B9),
    'Personal Hygiene': Color(0xFF8E44AD),
    'Cleaning & Sanitizing': Color(0xFF16A085),
    'Facility & Equipment': Color(0xFF34495E),
    'Food Safety Management': Color(0xFFB7950B),
  };

  /// FSME's free Find a Proctor service — offered on the completion
  /// screen as a neutral next step for someone who finished the free
  /// taste and didn't buy. Framed as "when you're ready," not a claim
  /// that they ARE ready.
  static const String _fsmeProctorUrl =
      'https://foodsafetymadeeasy.com/find-a-proctor/';

  /// Full question bank counts per category — used in the re-ask copy
  /// to show how many more are available. Approximate is fine; these
  /// come from the bank distribution noted in the diagnostic spec.
  static const Map<String, int> _bankCounts = {
    'Time & Temperature': 70,
    'Cross-Contamination': 42,
    'Cleaning & Sanitizing': 38,
    'Personal Hygiene': 36,
    'Food Preparation': 34,
    'Receiving & Storage': 44,
    'Facility & Equipment': 22,
    'Food Safety Management': 20,
    'Food Safety Foundations': 12,
    'Pathogens': 12,
    'Pest Management': 6,
  };

  List<String> _categories = [];
  Map<String, List<QuestionModel>> _categoryDecks = {};
  Map<String, int> _categoryProgress = {};

  int _currentCatIndex = 0;
  bool _loaded = false;

  // Question state
  String _questionText = '';
  String _answerAText = '';
  String _answerBText = '';
  int _correctSlot = 0;
  bool _answered = false;
  bool? _wasCorrect;

  // Answer button colors (real tool uses slate-blue idle, green/red/grey
  // on reveal).
  Color _colorA = const Color(0xFF4A6FA5);
  Color _colorB = const Color(0xFF4A6FA5);

  int _totalCorrect = 0;
  int _totalIncorrect = 0;
  int _totalAnswered = 0;

  // Category limit reached
  bool _showingLimit = false;

  // All done
  bool _allDone = false;

  // Slide animation for the question bubble.
  AnimationController? _slideController;
  Animation<Offset> _slideOffset = const AlwaysStoppedAnimation(Offset.zero);

  // ── FSME (completion screen only) ───────────────────────────────────
  /// Terminal lines revealed so far in the completion FSME box.
  final List<String> _fsmeLines = [];
  bool _fsmeStarted = false;

  int _gazeTarget = 0;
  double _gazeCurrent = 0.0;
  Timer? _gazeTimer;
  AnimationController? _gazeAnim;
  AnimationController? _blinkController;
  Timer? _blinkTimer;
  final Random _rng = Random();

  static const Color _eyeRed = Color(0xFFE24B4A);

  /// FSME's snarky completion readout, typed one line at a time.
  static const List<String> _fsmeScript = [
    'Okay. You got a taste of the SafePrep experience.',
    'Running assessment script ..........',
    'Subject is intelligent... subject is capable...',
    'Subject retained an ALARMING amount of food safety '
        'knowledge in a very short window ............',
    'Conclusion: ...divine intervention? Mind-meld program '
        'actually worked? ...No. Nobody learns THAT fast.',
    '...Subject is a robot. Subject has to be a robot.',
    '...wait. Boss? Is that you? Are you messing with me again?',
    "...Okay. Okay, I'll play along.",
    'Since you already know everything, all that\u2019s left is to '
        'find a local proctor and make it official.',
    'Here \u2014 use this. It\u2019s free. Congratulations.',
  ];

  DiagnosticResult get _result =>
      OnboardingAnswers.instance.diagnosticResult ?? const DiagnosticResult([]);

  Color get _currentColor {
    final cat = _currentCatIndex < _categories.length
        ? _categories[_currentCatIndex]
        : '';
    return _categoryColors[cat] ?? _gold;
  }

  @override
  void initState() {
    super.initState();
    MixpanelService.instance.track(
      'SpOn_RefLtd_Viewed',
      properties: {'app_name': 'SP'},
    );
    _loadDecks();
  }

  @override
  void dispose() {
    _slideController?.dispose();
    _gazeAnim?.dispose();
    _blinkController?.dispose();
    _gazeTimer?.cancel();
    _blinkTimer?.cancel();
    super.dispose();
  }

  // ── FSME (completion) ───────────────────────────────────────────────

  /// Kicks off the FSME eyes + typed readout. Called once, the first
  /// time the completion view builds.
  void _startFsme() {
    if (_fsmeStarted) return;
    _fsmeStarted = true;

    _gazeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(_advanceGaze);
    _gazeAnim!.repeat();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    _scheduleGaze();
    _scheduleBlink();
    _revealFsme();
  }

  Future<void> _revealFsme() async {
    await Future.delayed(const Duration(milliseconds: 400));
    for (final line in _fsmeScript) {
      if (!mounted) return;
      setState(() => _fsmeLines.add(line));
      await Future.delayed(const Duration(milliseconds: 900));
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
      await _blinkController?.forward(from: 0.0);
      if (mounted) await _blinkController?.reverse();
      _scheduleBlink();
    });
  }

  Future<void> _launchProctor() async {
    MixpanelService.instance.track(
      'SpOn_RefLtd_ProctorFinder',
      properties: {'app_name': 'SP'},
    );
    final uri = Uri.parse(_fsmeProctorUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _loadDecks() async {
    // Get the 3 weakest categories from the diagnostic.
    final weakest = _result.weakestCategories.take(3).toList();
    if (weakest.isEmpty) {
      // Fallback if somehow no weak categories (shouldn't happen on
      // the decline path, but defensive).
      weakest.addAll([
        'Time & Temperature',
        'Cross-Contamination',
        'Personal Hygiene',
      ]);
    }
    while (weakest.length < 3) {
      for (final cat in [
        'Time & Temperature',
        'Cross-Contamination',
        'Cleaning & Sanitizing',
        'Personal Hygiene',
      ]) {
        if (!weakest.contains(cat)) {
          weakest.add(cat);
          if (weakest.length >= 3) break;
        }
      }
    }

    final all = await QuestionLoader.loadAll(shuffle: false);
    final decks = <String, List<QuestionModel>>{};
    final progress = <String, int>{};

    for (final cat in weakest) {
      final questions =
          all
              .where((q) => q.category.toLowerCase() == cat.toLowerCase())
              .toList()
            ..shuffle();
      decks[cat] = questions.take(_questionsPerCategory).toList();
      progress[cat] = 0;
    }

    if (!mounted) return;
    setState(() {
      _categories = weakest;
      _categoryDecks = decks;
      _categoryProgress = progress;
      _loaded = true;
    });

    _loadQuestion();
  }

  Future<void> _loadQuestion() async {
    if (_currentCatIndex >= _categories.length) {
      setState(() => _allDone = true);
      return;
    }

    final cat = _categories[_currentCatIndex];
    final deck = _categoryDecks[cat] ?? [];
    final progress = _categoryProgress[cat] ?? 0;

    if (progress >= deck.length || progress >= _questionsPerCategory) {
      setState(() => _showingLimit = true);
      return;
    }

    final q = deck[progress];
    final answers = [q.answer1, q.answer2, q.answer3, q.answer4];
    final correctText = answers[q.correctAnswer];
    final wrongs = <String>[];
    for (int i = 0; i < answers.length; i++) {
      if (i != q.correctAnswer) wrongs.add(answers[i]);
    }
    wrongs.shuffle();

    final slot = Random().nextInt(2);

    setState(() {
      _questionText = q.questionText;
      _correctSlot = slot;
      _answerAText = slot == 0 ? correctText : wrongs[0];
      _answerBText = slot == 1 ? correctText : wrongs[0];
      _answered = false;
      _wasCorrect = null;
      _showingLimit = false;
      _colorA = const Color(0xFF4A6FA5);
      _colorB = const Color(0xFF4A6FA5);
    });

    await _slideIn();
  }

  Future<void> _slideIn() async {
    _slideController?.dispose();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _slideInMs),
    );
    _slideOffset = Tween<Offset>(begin: const Offset(1.5, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _slideController!,
            curve: Curves.easeOutCubic,
          ),
        );
    if (mounted) setState(() {});
    await _slideController!.forward();
  }

  Future<void> _slideOut() async {
    _slideController?.dispose();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _slideOutMs),
    );
    _slideOffset = Tween<Offset>(begin: Offset.zero, end: const Offset(-1.5, 0))
        .animate(
          CurvedAnimation(parent: _slideController!, curve: Curves.easeInCubic),
        );
    if (mounted) setState(() {});
    await _slideController!.forward();
  }

  void _onAnswer(bool tappedA) {
    if (_answered) return;

    final isCorrect =
        (tappedA && _correctSlot == 0) || (!tappedA && _correctSlot == 1);

    final cat = _categories[_currentCatIndex];

    setState(() {
      _answered = true;
      _wasCorrect = isCorrect;
      _totalAnswered++;
      if (isCorrect) {
        _totalCorrect++;
      } else {
        _totalIncorrect++;
      }
      _categoryProgress[cat] = (_categoryProgress[cat] ?? 0) + 1;

      // Reveal colors, matching the real tool: correct slot green, the
      // tapped-wrong slot red, the other loser greyed.
      if (isCorrect) {
        if (tappedA) {
          _colorA = _green;
          _colorB = const Color(0xFF888888);
        } else {
          _colorB = _green;
          _colorA = const Color(0xFF888888);
        }
      } else {
        if (tappedA) {
          _colorA = _red;
          _colorB = _green;
        } else {
          _colorB = _red;
          _colorA = _green;
        }
      }
    });

    MixpanelService.instance.track(
      'SpOn_RefLtd_Answered',
      properties: {
        'app_name': 'SP',
        'category': cat,
        'correct': isCorrect,
        'question_in_category': _categoryProgress[cat],
      },
    );

    // Auto-advance after a beat: slide the current card out, then load
    // the next.
    Future.delayed(const Duration(milliseconds: 900), () async {
      if (!mounted) return;
      await _slideOut();
      if (!mounted) return;
      _loadQuestion();
    });
  }

  void _continueToNextCategory() {
    MixpanelService.instance.track(
      'SpOn_RefLtd_CatLimit',
      properties: {'app_name': 'SP', 'category': _categories[_currentCatIndex]},
    );

    setState(() {
      _currentCatIndex++;
      _showingLimit = false;
    });
    _loadQuestion();
  }

  /// Shared $4.99 unlock. Triggers the real IAP; only a VERIFIED success
  /// opens the app (straight to the user's weakest category, matching the
  /// post-purchase route). Cancel or failure returns to the paywall.
  bool _purchasing = false;

  Future<void> _unlock(String source) async {
    if (_purchasing) return;
    setState(() => _purchasing = true);

    MixpanelService.instance.track(
      'SpOn_Purchase',
      properties: {
        'app_name': 'SP',
        'tier': 'sp',
        'source': source,
        'price': '\$4.99',
      },
    );

    final result = await IAPService.instance.buySevenDay();
    if (!mounted) return;
    setState(() => _purchasing = false);

    if (result == IAPResult.success) {
      final weakest = _result.weakestCategories.isNotEmpty
          ? _result.weakestCategories.first
          : 'Time & Temperature';
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => CategoryStudyPage(category: weakest)),
        (_) => false,
      );
    } else {
      // Cancel or fail → back to the paywall to decide again.
      if (Navigator.canPop(context)) Navigator.pop(context);
      final message = result.userMessage;
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  // ── Build methods ───────────────────────────────────────────────

  Widget _limitedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: _gold.withValues(alpha: 0.12),
      child: Text(
        'LIMITED VERSION  \u2022  $_totalAnswered of '
        '${_categories.length * _questionsPerCategory} free questions',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: _gold,
        ),
      ),
    );
  }

  Widget _questionView() {
    final cat = _currentCatIndex < _categories.length
        ? _categories[_currentCatIndex]
        : '';
    final progress = _categoryProgress[cat] ?? 0;
    final color = _currentColor;

    return Column(
      children: [
        // Category accent strip, matching the real tool.
        Container(height: 3, color: color.withValues(alpha: 0.4)),

        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                '$progress of $_questionsPerCategory',
                style: TextStyle(
                  fontSize: 12,
                  color: _softWhite.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Speech-bubble question card + answer buttons, sliding as a unit.
        SlideTransition(
          position: _slideOffset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _questionBubble(color),
              const SizedBox(height: 16),
              _answerButtons(),
            ],
          ),
        ),

        const SizedBox(height: 24),

        _scoreCounters(),
      ],
    );
  }

  Widget _questionBubble(Color color) {
    return CustomPaint(
      painter: _BubblePainter(color: color),
      child: SizedBox(
        width: 320,
        height: 150,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Center(
            child: Text(
              _questionText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _answerButtons() {
    return SizedBox(
      width: 320,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _answerButton(
                'A',
                _answerAText,
                _colorA,
                () => _onAnswer(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _answerButton(
                'B',
                _answerBText,
                _colorB,
                () => _onAnswer(false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _answerButton(
    String label,
    String text,
    Color bg,
    VoidCallback onTap,
  ) {
    return ElevatedButton(
      onPressed: _answered ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        disabledBackgroundColor: bg,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 72),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0x99FFFFFF),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _scoreCounters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Expanded(
            child: _scoreBox(
              '\u2713 Correct',
              '$_totalCorrect',
              const Color(0xFFE8F5E9),
              const Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _scoreBox(
              '\u2717 Incorrect',
              '$_totalIncorrect',
              const Color(0xFFFFEBEE),
              const Color(0xFFC62828),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _scoreBox(
              '\u2014 Total',
              '$_totalAnswered',
              const Color(0xFFF5F5F5),
              const Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBox(String label, String value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  /// The re-ask screen — fires when a category hits its 5-question limit.
  /// Names the category, states how many more are in the full version,
  /// and offers the unlock. This is the conversion moment.
  Widget _categoryLimitView() {
    final cat = _categories[_currentCatIndex];
    final bankTotal = _bankCounts[cat] ?? 30;
    final remaining = bankTotal - _questionsPerCategory;
    final hasMoreCategories = _currentCatIndex < _categories.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 40, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 30),

          Icon(Icons.lock_outline, size: 32, color: _gold),

          const SizedBox(height: 14),

          Text(
            'That\u2019s your $_questionsPerCategory free questions\nin $cat.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _softWhite,
              height: 1.35,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'There are $remaining more \u2014 and it\u2019s your weakest area.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _softWhite.withValues(alpha: 0.5),
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          // Unlock button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _purchasing ? null : () => _unlock('cat_limit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _darkBg,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSizes.buttonCornerRadius,
                  ),
                ),
              ),
              child: const Text(
                'Unlock SafePrep  \u2014  \$4.99',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          const SizedBox(height: 14),

          if (hasMoreCategories)
            GestureDetector(
              onTap: _continueToNextCategory,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Continue to next category  \u2192',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _gold,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// One glowing red eye that darts and blinks.
  Widget _davEye() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _gazeAnim ?? const AlwaysStoppedAnimation(0.0),
        _blinkController ?? const AlwaysStoppedAnimation(0.0),
      ]),
      builder: (context, _) {
        final blink = 1.0 - (_blinkController?.value ?? 0.0) * 0.92;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(1.0, blink),
          child: Container(
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
                  color: _eyeRed.withValues(alpha: 0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: _eyeRed.withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Transform.translate(
                offset: Offset(_gazeCurrent * 7, 1),
                child: Container(
                  width: 13,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0000),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// FSME completion box — animated eyes + snarky typed readout, then the
  /// free proctor-finder offer as a tappable exit.
  Widget _fsmeBox() {
    final bool done = _fsmeLines.length >= _fsmeScript.length;

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
          constraints: const BoxConstraints(minHeight: 80),
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
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    '> $line',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      height: 1.5,
                      color: _gold.withValues(alpha: 0.85),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Proctor finder — appears once the readout finishes. Framed as
        // "when you're ready," a tappable exit, not an auto-launch.
        if (done) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: _launchProctor,
              style: OutlinedButton.styleFrom(
                foregroundColor: _gold,
                side: BorderSide(color: _gold.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSizes.buttonCornerRadius,
                  ),
                ),
              ),
              child: const Text(
                'Find a proctor near me  \u2192',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Final screen after all 15 questions — one more conversion moment.
  Widget _completionView() {
    // Kick off FSME the first time this view renders — deferred to after
    // the frame so we never call setState during build.
    if (!_fsmeStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startFsme());
    }

    final pct = _totalAnswered > 0
        ? ((_totalCorrect / _totalAnswered) * 100).round()
        : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 40, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 30),

          Text(
            'LIMITED VERSION COMPLETE',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
              color: _gold,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            '$_totalCorrect of $_totalAnswered correct',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _softWhite,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            '$pct% across your 3 weakest categories',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _softWhite.withValues(alpha: 0.5),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'That was 15 questions out of 500+.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _softWhite.withValues(alpha: 0.4),
              fontStyle: FontStyle.italic,
            ),
          ),

          const SizedBox(height: 28),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _purchasing ? null : () => _unlock('completion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _darkBg,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSizes.buttonCornerRadius,
                  ),
                ),
              ),
              child: const Text(
                'Unlock SafePrep  \u2014  \$4.99',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // FSME's snarky sign-off + free proctor-finder exit.
          _fsmeBox(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        backgroundColor: _darkBg,
        body: Center(child: CircularProgressIndicator(color: _gold)),
      );
    }

    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: Column(
          children: [
            _limitedBanner(),
            Expanded(
              child: SingleChildScrollView(
                child: _allDone
                    ? _completionView()
                    : _showingLimit
                    ? _categoryLimitView()
                    : _questionView(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Speech-bubble painter — copied from the real RapidFirePage so the
/// limited version's question card reads identically.
class _BubblePainter extends CustomPainter {
  final Color color;
  const _BubblePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(20, 0)
      ..quadraticBezierTo(0, 0, 0, 20)
      ..lineTo(0, 100)
      ..quadraticBezierTo(0, 120, 20, 120)
      ..lineTo(30, 120)
      ..lineTo(20, 145)
      ..lineTo(60, 120)
      ..lineTo(300, 120)
      ..quadraticBezierTo(320, 120, 320, 100)
      ..lineTo(320, 20)
      ..quadraticBezierTo(320, 0, 300, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.color != color;
}
