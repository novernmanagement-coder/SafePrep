import 'package:flutter/material.dart';
import 'constants.dart';
import 'csv_loader.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'dashboard_page.dart';
import 'category_quiz_results_page.dart';
import 'safe_prep_nav_bar.dart';

class CategoryQuizPage extends StatefulWidget {
  final String category;
  const CategoryQuizPage({super.key, required this.category});

  @override
  State<CategoryQuizPage> createState() => _CategoryQuizPageState();
}

class _CategoryQuizPageState extends State<CategoryQuizPage> {
  final AppState _state = AppState();
  List<QuestionModel> _questions = [];
  int _currentIndex = 0;
  int _correctCount = 0;
  int _selectedIndex = -1;
  bool _answered = false;
  bool _loaded = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _determineMode() {
    if (!_state.hasScoreForCategory(widget.category)) return 'Standard';
    final score = _state.getCategoryScore(widget.category);
    if (score < 50) return 'Recovery';
    if (score < 85) return 'Assessment';
    return 'Standard';
  }

  Future<void> _loadQuestions() async {
    final mode = _determineMode();
    final all = await QuestionLoader.loadByCategory(
      widget.category,
      shuffle: false,
    );
    if (all.isEmpty) {
      setState(() => _loaded = true);
      return;
    }

    const target = 15;
    final selected = <QuestionModel>[];
    final usedIds = <String>{};

    double hardRatio, mediumRatio;
    switch (mode) {
      case 'Recovery':
        hardRatio = AppConstants.quizHardRatioRecovery;
        mediumRatio = AppConstants.quizMediumRatioRecovery;
        break;
      case 'Assessment':
        hardRatio = AppConstants.quizHardRatioAssessment;
        mediumRatio = AppConstants.quizMediumRatioAssessment;
        break;
      default:
        hardRatio = AppConstants.quizHardRatioStandard;
        mediumRatio = AppConstants.quizMediumRatioStandard;
    }

    final mustInclude = all.where((q) => q.mustInclude == 1).toList()
      ..shuffle();
    final taken = mustInclude.take(target).toList();
    selected.addAll(taken);
    for (final q in taken) {
      usedIds.add(q.id);
    }

    int remaining = target - selected.length;
    if (remaining > 0) {
      final pool = all.where((q) => !usedIds.contains(q.id)).toList();
      final hardCount = (remaining * hardRatio).round();
      final mediumCount = (remaining * mediumRatio).round();
      final easyCount = remaining - hardCount - mediumCount;

      final hard = pool.where((q) => q.difficulty == 3).toList()..shuffle();
      final medium = pool.where((q) => q.difficulty == 2).toList()..shuffle();
      final easy = pool.where((q) => q.difficulty == 1).toList()..shuffle();

      final fill = [
        ...hard.take(hardCount),
        ...medium.take(mediumCount),
        ...easy.take(easyCount),
      ];

      if (fill.length < remaining) {
        final fallback =
            pool.where((q) => !fill.any((f) => f.id == q.id)).toList()
              ..shuffle();
        fill.addAll(fallback.take(remaining - fill.length));
      }

      selected.addAll(fill.take(remaining));
    }

    selected.shuffle();

    // Randomize answer positions for each question (anti-muscle-memory)
    final shuffled = selected.take(target).map((q) => q.shuffled()).toList();

    setState(() {
      _questions = shuffled;
      _loaded = true;
    });
  }

  void _answerSelected(int index) {
    if (_answered || _currentIndex >= _questions.length) return;

    final q = _questions[_currentIndex];
    final correct = index == q.correctAnswer;

    if (correct) _correctCount++;

    setState(() {
      _selectedIndex = index;
      _answered = true;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _nextQuestion() {
    if (_currentIndex >= _questions.length - 1) {
      _showResults();
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedIndex = -1;
      _answered = false;
    });
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _showResults() {
    final score = _questions.isEmpty
        ? 0
        : (_correctCount * 100) ~/ _questions.length;
    _state.saveCategoryQuizScore(widget.category, score);
    _state.markCategoryStudied(widget.category);
    AppStatePersistence.save();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryQuizResultsPage(
          category: widget.category,
          correctCount: _correctCount,
          totalCount: _questions.length,
        ),
      ),
    );
  }

  Color _answerColor(int index, int correctAnswer) {
    if (!_answered) return AppColors.primaryButton;
    if (index == correctAnswer) return AppColors.scoreBand4;
    if (index == _selectedIndex) return AppColors.scoreBand1;
    return AppColors.primaryButton;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFE3F0F9),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final hasQuestions = _questions.isNotEmpty;
    final q = hasQuestions && _currentIndex < _questions.length
        ? _questions[_currentIndex]
        : null;
    final isLast = _currentIndex == _questions.length - 1;
    final correct = _answered && q != null && _selectedIndex == q.correctAnswer;

    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Padding(
          padding: AppSizes.pageMargin,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    spacing: 10,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 10),
                        child: Column(
                          spacing: 4,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const DashboardPage(),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Safe',
                                        style: TextStyle(
                                          fontSize: AppFonts.header,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.bodyText,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Image.asset(
                                        'Assets/splash.png',
                                        width: 36,
                                        height: 36,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Prep™',
                                        style: TextStyle(
                                          fontSize: AppFonts.header,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.bodyText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              widget.category,
                              style: TextStyle(
                                fontSize: AppFonts.subheader,
                                fontWeight: FontWeight.w600,
                                color: AppColors.bodyText,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (hasQuestions)
                              Text(
                                'Question ${_currentIndex + 1} of ${_questions.length}',
                                style: TextStyle(
                                  fontSize: AppFonts.caption,
                                  color: AppColors.subtleText,
                                ),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),

                      if (!hasQuestions)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(
                              AppSizes.cardCornerRadius,
                            ),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Text(
                            'No quiz questions available for this category yet.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.strongText,
                            ),
                          ),
                        ),

                      if (hasQuestions && q != null) ...[
                        // Question card
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(
                              AppSizes.cardCornerRadius,
                            ),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Text(
                            q.questionText,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.strongText,
                              height: 1.5,
                            ),
                          ),
                        ),

                        // Answer buttons
                        ...[
                          q.answer1,
                          q.answer2,
                          q.answer3,
                          q.answer4,
                        ].asMap().entries.map((e) {
                          final i = e.key;
                          final text = e.value;
                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _answered
                                  ? null
                                  : () => _answerSelected(i),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _answerColor(
                                  i,
                                  q.correctAnswer,
                                ),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _answerColor(
                                  i,
                                  q.correctAnswer,
                                ),
                                disabledForegroundColor: Colors.white,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                minimumSize: Size(
                                  double.infinity,
                                  AppSizes.primaryButtonHeight,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.buttonCornerRadius,
                                  ),
                                ),
                              ),
                              child: Text(
                                text,
                                style: const TextStyle(fontSize: 13),
                                textAlign: TextAlign.left,
                              ),
                            ),
                          );
                        }),

                        // Feedback card
                        if (_answered)
                          Container(
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: correct
                                  ? const Color(0xFF3BA776)
                                  : const Color(0xFFD64545),
                              borderRadius: BorderRadius.circular(
                                AppSizes.cardCornerRadius,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 8,
                              children: [
                                Text(
                                  correct ? 'Correct.' : 'Not quite.',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  q.explanation,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    height: 1.5,
                                  ),
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  height: AppSizes.primaryButtonHeight,
                                  child: ElevatedButton(
                                    onPressed: _nextQuestion,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppColors.strongText,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSizes.buttonCornerRadius,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      isLast
                                          ? 'See results'
                                          : 'Next question →',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],

                      // Footer
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          spacing: AppSizes.footerSpacing,
                          children: [
                            Text(
                              AppStrings.footerLine1,
                              style: TextStyle(
                                fontSize: AppFonts.footer,
                                color: AppColors.footerText,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              AppStrings.footerLine2,
                              style: TextStyle(
                                fontSize: AppFonts.footer,
                                color: AppColors.footerText,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              AppStrings.footerLine3,
                              style: TextStyle(
                                fontSize: AppFonts.footer,
                                color: AppColors.starMotifBlue,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SafePrepNavBar(),
            ],
          ),
        ),
      ),
    );
  }
}
