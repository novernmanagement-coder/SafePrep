import 'package:flutter/material.dart';
import 'constants.dart';
import 'csv_loader.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'home_page.dart';
import 'dashboard_page.dart';
import 'category_study_page.dart';
import 'category_quiz_page.dart';
import 'readiness_engine.dart';
import 'recomputing_modal.dart';
import 'safe_prep_nav_bar.dart';

class CategoryQuizResultsPage extends StatefulWidget {
  final String category;
  final int correctCount;
  final int totalCount;

  const CategoryQuizResultsPage({
    super.key,
    required this.category,
    required this.correctCount,
    required this.totalCount,
  });

  @override
  State<CategoryQuizResultsPage> createState() =>
      _CategoryQuizResultsPageState();
}

class _CategoryQuizResultsPageState extends State<CategoryQuizResultsPage> {
  final AppState _state = AppState();
  String _tickerFacts = '';

  @override
  void initState() {
    super.initState();
    _loadFacts();
    _saveScore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RecomputingModal.show(
        context,
        category: widget.category,
        readinessScore: _state.readinessScore,
      );
    });
  }

  Future<void> _loadFacts() async {
    var facts = await FactLoader.loadByCategory(widget.category);
    if (facts.isEmpty) facts = await FactLoader.loadAll();
    setState(() {
      _tickerFacts = facts.map((f) => f.fact).join('  •  ');
    });
  }

  void _saveScore() {
    final percent = widget.totalCount == 0
        ? 0
        : (widget.correctCount * 100) ~/ widget.totalCount;
    _state.saveCategoryQuizScore(widget.category, percent);
    _state.incrementCategoryQuizAttempts(widget.category);

    _state.readinessScore = ReadinessEngine.calculate(_state);
    _state.readinessCoachMessage = ReadinessEngine.coachMessage(
      _state,
      _state.readinessScore,
    );
    _state.readinessCheerMessage = ReadinessEngine.cheerleaderMessage(
      _state,
      _state.readinessScore,
    );

    AppStatePersistence.save();
  }

  Color _scoreColor(int percent) {
    if (percent <= 50) return AppColors.scoreBand1;
    if (percent <= 65) return AppColors.scoreBand2;
    if (percent <= 84) return AppColors.scoreBand3;
    return AppColors.scoreBand4;
  }

  String _scoreMessage(int percent) {
    if (percent == 100) return 'Perfect. You know this category cold.';
    if (percent >= 80) return 'Strong work. You\'re close to mastering this.';
    if (percent >= 60) {
      return 'Good foundation. A little more review will lock it in.';
    }
    return 'This one needs more work — and that\'s okay. Study it again.';
  }

  @override
  Widget build(BuildContext context) {
    final percent = widget.totalCount == 0
        ? 0
        : (widget.correctCount * 100) ~/ widget.totalCount;
    final scoreColor = _scoreColor(percent);

    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: AppSizes.pageMargin,
                child: Column(
                  spacing: 12,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HomePage(),
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
                    ),

                    Text(
                      widget.category,
                      style: TextStyle(
                        fontSize: AppFonts.header,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bodyText,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (_tickerFacts.isNotEmpty)
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F0E8),
                          border: Border.all(color: const Color(0xFFC8B89A)),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Marquee(text: _tickerFacts),
                        ),
                      ),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        spacing: 8,
                        children: [
                          Text(
                            '${widget.correctCount}/${widget.totalCount}',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: scoreColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            '$percent%',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.subtleText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            _scoreMessage(percent),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.bodyText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(
                      width: double.infinity,
                      height: AppSizes.primaryButtonHeight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CategoryStudyPage(category: widget.category),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButton,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.buttonCornerRadius,
                            ),
                          ),
                        ),
                        child: const Text('Study this category again'),
                      ),
                    ),

                    SizedBox(
                      width: double.infinity,
                      height: AppSizes.primaryButtonHeight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CategoryQuizPage(category: widget.category),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButton,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.buttonCornerRadius,
                            ),
                          ),
                        ),
                        child: const Text('Retake Quiz'),
                      ),
                    ),

                    SizedBox(
                      width: double.infinity,
                      height: AppSizes.primaryButtonHeight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DashboardPage(),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButton,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.buttonCornerRadius,
                            ),
                          ),
                        ),
                        child: const Text('Back to Dashboard'),
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
    );
  }
}
