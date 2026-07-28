import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
/// Separate file from rapid_fire_page.dart intentionally. The full
/// trainer is a tool; this is a funnel stage that uses the tool's
/// mechanics. Mixing the two would compromise both.
class RapidFireLimitedPage extends StatefulWidget {
  const RapidFireLimitedPage({super.key});

  @override
  State<RapidFireLimitedPage> createState() => _RapidFireLimitedPageState();
}

class _RapidFireLimitedPageState extends State<RapidFireLimitedPage> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _red = Color(0xFFC62828);

  static const int _questionsPerCategory = 5;

  /// Splash reads this flag to skip the full onboarding for returners.
  /// Once set, the user keeps permanent access to the limited Rapid Fire
  /// and sees the decline page (with the purchase button) on relaunch
  /// instead of the full diagnostic funnel.
  static const String declinedToLimitedKey = 'has_declined_to_limited';

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
  int _currentQIndex = 0;
  bool _loaded = false;

  // Question state
  String _questionText = '';
  String _answerAText = '';
  String _answerBText = '';
  int _correctSlot = 0;
  bool _answered = false;
  bool? _wasCorrect;

  int _totalCorrect = 0;
  int _totalAnswered = 0;

  // Category limit reached
  bool _showingLimit = false;

  // All done
  bool _allDone = false;

  DiagnosticResult get _result =>
      OnboardingAnswers.instance.diagnosticResult ?? const DiagnosticResult([]);

  @override
  void initState() {
    super.initState();
    _setDeclinedFlag();
    MixpanelService.instance.track(
      'rapid_fire_limited_started',
      properties: {'app_name': 'SP'},
    );
    _loadDecks();
  }

  Future<void> _setDeclinedFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(declinedToLimitedKey, true);
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

  void _loadQuestion() {
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
    });
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
      if (isCorrect) _totalCorrect++;
      _categoryProgress[cat] = (_categoryProgress[cat] ?? 0) + 1;
    });

    MixpanelService.instance.track(
      'rapid_fire_limited_answered',
      properties: {
        'app_name': 'SP',
        'category': cat,
        'correct': isCorrect,
        'question_in_category': _categoryProgress[cat],
      },
    );

    // Auto-advance after a beat
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _loadQuestion();
    });
  }

  void _continueToNextCategory() {
    MixpanelService.instance.track(
      'rapid_fire_limited_category_limit',
      properties: {'app_name': 'SP', 'category': _categories[_currentCatIndex]},
    );

    setState(() {
      _currentCatIndex++;
      _showingLimit = false;
    });
    _loadQuestion();
  }

  void _exitToDashboard() {
    MixpanelService.instance.track(
      'rapid_fire_limited_exited',
      properties: {
        'app_name': 'SP',
        'total_answered': _totalAnswered,
        'total_correct': _totalCorrect,
      },
    );
    // Free tool never grants app access — pop back to the paywall.
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  /// Shared $4.99 unlock. Triggers the real IAP; only a VERIFIED success
  /// opens the app (straight to the user's weakest category, matching the
  /// post-purchase route). Cancel or failure returns to the paywall.
  bool _purchasing = false;

  Future<void> _unlock(String source) async {
    if (_purchasing) return;
    setState(() => _purchasing = true);

    MixpanelService.instance.track(
      'rapid_fire_limited_purchase',
      properties: {'app_name': 'SP', 'source': source, 'price': '\$4.99'},
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
        'LIMITED VERSION  \u2022  ${_totalAnswered} of ${_categories.length * _questionsPerCategory} free questions',
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

    Color colorA = const Color(0xFF4A6FA5);
    Color colorB = const Color(0xFF4A6FA5);

    if (_answered && _wasCorrect != null) {
      if (_wasCorrect!) {
        colorA = _correctSlot == 0 ? _green : const Color(0xFF888888);
        colorB = _correctSlot == 1 ? _green : const Color(0xFF888888);
      } else {
        colorA = _correctSlot == 0 ? _green : _red;
        colorB = _correctSlot == 1 ? _green : _red;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Category + progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _gold,
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

          const SizedBox(height: 16),

          // Question
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withValues(alpha: 0.2), width: 1),
            ),
            child: Text(
              _questionText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _softWhite,
                height: 1.45,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Answer buttons
          Row(
            children: [
              Expanded(
                child: _answerButton(
                  'A',
                  _answerAText,
                  colorA,
                  () => _onAnswer(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _answerButton(
                  'B',
                  _answerBText,
                  colorB,
                  () => _onAnswer(false),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Score
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$_totalCorrect correct',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _green,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${_totalAnswered - _totalCorrect} missed',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _red,
                ),
              ),
            ],
          ),
        ],
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
        minimumSize: const Size(0, 80),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
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
              onPressed: _purchasing ? null : () => _unlock('category_limit'),
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

  /// Final screen after all 15 questions — one more conversion moment.
  Widget _completionView() {
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

          const SizedBox(height: 14),

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
