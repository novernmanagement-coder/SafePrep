import 'package:flutter/material.dart';
import 'constants.dart';
import 'csv_loader.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'dashboard_page.dart';
import 'assessment_info_page.dart';
import 'category_quiz_page.dart';
import 'mixpanel_service.dart';

class CategoryStudyPage extends StatefulWidget {
  final String category;

  const CategoryStudyPage({super.key, required this.category});

  @override
  State<CategoryStudyPage> createState() => _CategoryStudyPageState();
}

class _CategoryStudyPageState extends State<CategoryStudyPage> {
  final AppState _state = AppState();
  List<CurriculumModel> _queue = [];
  int _currentIndex = 0;
  bool _loaded = false;
  String _mode = 'Standard';

  @override
  void initState() {
    super.initState();
    _loadCurriculum();
  }

  String _determineMode() {
    if (!_state.hasScoreForCategory(widget.category)) return 'Standard';
    final score = _state.getCategoryScore(widget.category);
    if (score < 50) return 'Recovery';
    if (score < 85) return 'Assessment';
    return 'Standard';
  }

  Future<void> _loadCurriculum() async {
    _mode = _determineMode();
    final all = await CurriculumLoader.loadByCategory(widget.category, _mode);
    setState(() {
      _queue = all;
      _loaded = true;
    });
    MixpanelService.instance.track(
      'study_started',
      properties: {
        'category': widget.category,
        'mode': _mode,
        'card_count': _queue.length,
      },
    );
  }

  List<String> _buildKeyPoints(CurriculumModel content) {
    if (content.keyPoints.isNotEmpty) {
      return content.keyPoints
          .split('|')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
    }
    return content.content
        .split('.')
        .map((s) => s.trim())
        .where((s) => s.length > 8)
        .take(5)
        .map((s) => '$s.')
        .toList();
  }

  void _goNext() {
    if (_currentIndex == _queue.length - 1) {
      MixpanelService.instance.track(
        'study_completed',
        properties: {'category': widget.category, 'mode': _mode},
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryQuizPage(category: widget.category),
        ),
      );
      return;
    }
    setState(() => _currentIndex++);
  }

  void _goPrevious() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
  }

  Widget _buildHeader() {
    return Padding(
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
                  MaterialPageRoute(builder: (_) => const DashboardPage()),
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
                    Image.asset('Assets/splash.png', width: 36, height: 36),
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
          if (!_state.hasTakenAssessment)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Full Curriculum · ',
                  style: TextStyle(fontSize: 12, color: AppColors.subtleText),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AssessmentInfoPage(),
                    ),
                  ),
                  child: Text(
                    'Take the assessment to personalize',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryButton,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
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
          if (_queue.isNotEmpty)
            Text(
              _currentIndex < _queue.length
                  ? '${_currentIndex + 1} of ${_queue.length}'
                  : 'Complete',
              style: TextStyle(
                fontSize: AppFonts.caption,
                color: AppColors.subtleText,
              ),
              textAlign: TextAlign.center,
            ),
          if (_mode != 'Standard')
            Text(
              _mode == 'Assessment'
                  ? 'Current study mode: Focused Review'
                  : _mode == 'Recovery'
                  ? 'Current study mode: Extra Support'
                  : 'Current study mode: Review',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppColors.subtleText,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildConceptCard(CurriculumModel content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            content.subcategory.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.subtleText,
            ),
          ),
          Text(
            content.conceptTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.strongText,
            ),
          ),
          Divider(color: AppColors.divider),
          Text(
            content.content,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.bodyText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            "You've reviewed everything in this category.",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.strongText,
            ),
          ),
          Text(
            'Head back to the Dashboard to track your progress or move on to another category.',
            style: TextStyle(fontSize: 13, color: AppColors.bodyText),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyPointsCard(List<String> points) {
    if (points.isEmpty) return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.cardCornerRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KEY POINTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.subtleText,
            ),
          ),
          const SizedBox(height: 8),
          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4, right: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryButton,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(fontSize: 12, color: AppColors.bodyText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        backgroundColor: AppColors.servSafeBlue,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                Text(
                  'Preparing your personalized content...',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: AppColors.subtleText,
                  ),
                  textAlign: TextAlign.center,
                ),
                LinearProgressIndicator(
                  backgroundColor: AppColors.subtleText.withValues(alpha: 0.2),
                  color: AppColors.primaryButton,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isComplete = _queue.isEmpty || _currentIndex >= _queue.length;
    final content = isComplete ? null : _queue[_currentIndex];
    final keyPoints = content != null ? _buildKeyPoints(content) : <String>[];
    final isLast = _queue.isNotEmpty && _currentIndex == _queue.length - 1;

    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSizes.pageMargin,
          child: Column(
            children: [
              _buildHeader(),

              isComplete || content == null
                  ? _buildCompletionCard()
                  : _buildConceptCard(content),

              if (!isComplete) ...[
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: AppSizes.primaryButtonHeight,
                        child: ElevatedButton(
                          onPressed: _currentIndex > 0 ? _goPrevious : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryButton,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.disabledButton,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSizes.buttonCornerRadius,
                              ),
                            ),
                          ),
                          child: const Text('← Previous'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: AppSizes.primaryButtonHeight,
                        child: ElevatedButton(
                          onPressed: _goNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryButton,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSizes.buttonCornerRadius,
                              ),
                            ),
                          ),
                          child: Text(isLast ? 'Take Quiz' : 'Next →'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              SizedBox(
                width: double.infinity,
                height: AppSizes.primaryButtonHeight,
                child: ElevatedButton(
                  onPressed: () {
                    final allCardsViewed =
                        _queue.isEmpty || _currentIndex >= _queue.length - 1;
                    if (allCardsViewed) {
                      MixpanelService.instance.track(
                        'study_completed',
                        properties: {
                          'category': widget.category,
                          'mode': _mode,
                        },
                      );
                    } else {
                      MixpanelService.instance.track(
                        'study_abandoned',
                        properties: {
                          'category': widget.category,
                          'mode': _mode,
                          'cards_viewed': _currentIndex,
                          'total_cards': _queue.length,
                        },
                      );
                    }
                    _state.markCategoryStudied(widget.category);
                    AppStatePersistence.save();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const DashboardPage()),
                    );
                  },
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

              const SizedBox(height: 10),

              if (!isComplete && keyPoints.isNotEmpty)
                _buildKeyPointsCard(keyPoints),
            ],
          ),
        ),
      ),
    );
  }
}
