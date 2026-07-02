import 'dart:async';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'app_state.dart';
import 'csv_loader.dart';
import 'app_state_persistence.dart';
import 'iap_service.dart';
import 'readiness_engine.dart';
import 'assessment_info_page.dart';
import 'dashboard_page.dart';
import 'settings_page.dart';
import 'sixty_second_refresh_page.dart';
import 'about_proctors_page.dart';
import 'final_exam_intro_page.dart';
import 'peace_of_mind_page.dart';
import 'trial_timer_service.dart';
import 'preview/preview_cinematic_splash.dart';
import 'mixpanel_service.dart';
import 'preview/preview_reveal_page.dart';
import 'safe_prep_nav_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final AppState _state = AppState();
  String _currentFact = '';
  List<MilestoneModel> _milestones = [];

  // Local display-only ticker for the "Trial — mm:ss" countdown on Home.
  // Reads TrialTimerService.remainingSeconds; does not affect trial logic.
  Timer? _displayTicker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFacts();
    _loadMilestones();

    MixpanelService.instance.track(
      'session_start',
      properties: {'is_unlocked': _state.hasUnlockedApp, 'app_name': 'SP'},
    );
    MixpanelService.instance.track(
      'home_viewed',
      properties: {'is_unlocked': _state.hasUnlockedApp, 'app_name': 'SP'},
    );

    if (!_state.hasUnlockedApp) {
      MixpanelService.instance.track(
        'trial_started',
        properties: {'app_name': 'SP'},
      );
      if (!TrialTimerService.instance.isExpired) {
        TrialTimerService.instance.onTrialExpired = _onTrialExpired;
        TrialTimerService.instance.start();
        _startDisplayTicker();
      } else {
        _onTrialExpired();
      }
    }
  }

  void _startDisplayTicker() {
    _displayTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {}); // repaint to reflect TrialTimerService.remainingSeconds
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _displayTicker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused)
      MixpanelService.instance.track(
        'session_end',
        properties: {'app_name': 'SP'},
      );
  }

  void _onTrialExpired() {
    MixpanelService.instance.track(
      'trial_expired',
      properties: {'app_name': 'SP'},
    );
    _displayTicker?.cancel();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => PreviewRevealPage()),
      (route) => false,
    );
  }

  void _checkUnlockTrophy() {
    if (_state.hasUnlockedApp &&
        !_state.earnedTrophyIds.contains('AppUnlocked')) {
      _state.addEarnedMilestone('AppUnlocked', 'SafePrep Unlocked');
      AppStatePersistence.save();
    }
  }

  Future<void> _loadFacts() async {
    final facts = await FactLoader.loadAll();
    if (mounted)
      setState(() {
        _currentFact = facts.map((f) => f.fact).join('  •  ');
      });
  }

  Future<void> _loadMilestones() async {
    final all = await MilestoneLoader.loadAll();
    if (mounted) {
      _checkUnlockTrophy();
      _state.readinessScore = ReadinessEngine.calculate(_state);
      _state.readinessCoachMessage = ReadinessEngine.coachMessage(
        _state,
        _state.readinessScore,
      );
      _state.readinessCheerMessage = ReadinessEngine.cheerleaderMessage(
        _state,
        _state.readinessScore,
      );
      setState(() => _milestones = all);
    }
  }

  Widget _buildButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: AppSizes.primaryButtonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryButton,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.buttonCornerRadius),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: AppFonts.button)),
      ),
    );
  }

  static const Color _goldDark = Color(0xFFC8A84B);
  static const Color _goldLight = Color(0xFFFFF3C4);
  static const Color _goldText = Color(0xFF8B6914);

  bool _isEarned(MilestoneModel m) =>
      _state.earnedTrophyIds.contains(m.trigger);

  void _showInfoModal(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _goldDark, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8B6914),
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF555555),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(
                width: 100,
                height: 40,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _goldDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTrophyModal(BuildContext context, MilestoneModel m, bool earned) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _goldDark, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              Text(
                earned ? '🏆' : '🔒',
                style: const TextStyle(fontSize: 52),
                textAlign: TextAlign.center,
              ),
              Text(
                earned ? m.title : 'Locked',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                earned
                    ? m.message
                    : 'Take the assessment to unlock this trophy and increase your readiness score.',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF555555),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(
                width: 100,
                height: 40,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _goldDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Nice!',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrophyCard(MilestoneModel m, {bool elite = false}) {
    final earned = _isEarned(m);
    return GestureDetector(
      onTap: () => _showTrophyModal(context, m, earned),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
        decoration: BoxDecoration(
          color: earned
              ? (elite ? _goldLight : Colors.white)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: earned ? _goldDark : const Color(0xFFDDDDDD),
            width: earned ? (elite ? 2 : 1.5) : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (elite)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: earned ? _goldDark : const Color(0xFFEEEEEE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ELITE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: earned ? Colors.white : const Color(0xFFAAAAAA),
                      ),
                    ),
                  ),
                Text(
                  earned ? '🏆' : '🔒',
                  style: TextStyle(
                    fontSize: earned ? 34 : 26,
                    color: earned ? null : const Color(0xFFBBBBBB),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  m.title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: earned ? FontWeight.w600 : FontWeight.normal,
                    color: earned
                        ? (elite ? _goldText : const Color(0xFF1A1A1A))
                        : const Color(0xFFAAAAAA),
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            if (earned)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: _goldDark,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 11, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTrophyBox({
    required String title,
    required List<String> earnedCategories,
    required String emptyIcon,
    required String infoTitle,
    required String infoMessage,
  }) {
    const categories = AppState.allCategories;
    final earnedSlots = categories
        .where((c) => earnedCategories.contains(c))
        .toList();

    return GestureDetector(
      onTap: () => _showInfoModal(context, infoTitle, infoMessage),
      child: Container(
        height: 95,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8D5A0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _goldText,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            earnedSlots.isEmpty
                ? const Center(
                    child: Text(
                      '🔒',
                      style: TextStyle(fontSize: 22, color: Color(0xFFCCCCCC)),
                    ),
                  )
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          if (i >= earnedSlots.length)
                            return const SizedBox(width: 26);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _goldLight,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _goldDark, width: 1),
                              ),
                              child: const Center(
                                child: Text(
                                  '🏆',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      if (earnedSlots.length > 4) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (i) {
                            final idx = i + 4;
                            if (idx >= earnedSlots.length)
                              return const SizedBox(width: 26);
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: _goldLight,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: _goldDark,
                                    width: 1,
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    '🏆',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  // Flat seeded display value shown on the Home readiness meter before any
  // real assessment/quiz data exists. Display-only — never written to
  // _state.readinessScore, so trophies, the Final Exam gate, and the real
  // ReadinessEngine calculation are completely unaffected.
  static const int _seededReadinessDisplay = 62;

  Widget _buildReadinessMeter() {
    final hasRealData =
        _state.latestResult != null || _state.categoryQuizScores.isNotEmpty;
    final showSeeded = !hasRealData && !_state.hasUnlockedApp;
    final score = hasRealData
        ? _state.readinessScore
        : (showSeeded ? _seededReadinessDisplay : _state.readinessScore);
    final isGreenLight = score >= 100;
    String label;
    if (showSeeded)
      label = 'National avg — adapts as you study';
    else if (score >= 100)
      label = '🟢 Green Light';
    else if (score >= 85)
      label = 'Nearly Ready';
    else if (score >= 66)
      label = 'Almost There';
    else if (score >= 41)
      label = 'Building Momentum';
    else
      label = 'Keep Going';

    return GestureDetector(
      onTap: () => _showInfoModal(
        context,
        'ServSafe Readiness',
        'Before you\'ve studied, this shows a national average — just something to compare against, not your real score. The moment you study a category or take the assessment, your actual data takes over and your Readiness Score updates to reflect you. 100% means you\'re ready. Take the SafePrep Final Exam to prove it.',
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
        decoration: BoxDecoration(
          color: isGreenLight
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFFFFBF0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isGreenLight
                ? Colors.green.shade300
                : const Color(0xFFE8D5A0),
            width: isGreenLight ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            const Text(
              'ServSafe Readiness',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _goldText,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            _buildPartialStars(score),
            const SizedBox(height: 6),
            Text(
              '$score%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isGreenLight ? Colors.green.shade700 : _goldDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: isGreenLight ? Colors.green.shade600 : _goldText,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartialStars(int score) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final starMin = i * 20.0;
        final starMax = (i + 1) * 20.0;
        double fillFraction = 0.0;
        if (score >= starMax)
          fillFraction = 1.0;
        else if (score > starMin)
          fillFraction = (score - starMin) / 20.0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _buildPartialStar(fillFraction),
        );
      }),
    );
  }

  Widget _buildPartialStar(double fillFraction) {
    return SizedBox(
      width: 24,
      height: 26,
      child: Stack(
        children: [
          const Text(
            '★',
            style: TextStyle(
              fontSize: 22,
              color: Color(0xFFDDDDDD),
              height: 1.1,
            ),
          ),
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: fillFraction,
              child: const Text(
                '★',
                style: TextStyle(
                  fontSize: 22,
                  color: Color(0xFFC8A84B),
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessMarquee() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8D5A0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: ClipRect(
                    child: ReadinessMarqueeScroller(
                      text: _state.readinessCoachMessage,
                      color: const Color(0xFF1A5276),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Image.asset(
                'Assets/instructor_explaining.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(color: Color(0xFFE8D5A0), height: 1),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: ClipRect(
                    child: ReadinessMarqueeScroller(
                      text: _state.readinessCheerMessage,
                      color: const Color(0xFFC8A84B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Image.asset(
                'Assets/student_correct.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrialUnlockBanner() {
    if (_state.hasUnlockedApp) return const SizedBox();
    return GestureDetector(
      onTap: () {
        MixpanelService.instance.track(
          'paywall_viewed',
          properties: {'source': 'home_page_banner', 'app_name': 'SP'},
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => PreviewRevealPage()),
          (route) => false,
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('⭐', style: TextStyle(fontSize: 14)),
            SizedBox(width: 8),
            Text(
              'Unlock Full Access — starting at \$4.99',
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Trial countdown display (replaces the curriculum button during trial) ──
  // PASSIVE — no tap action, per spec.
  Widget _buildTrialCountdown() {
    final remaining = TrialTimerService.instance.remainingSeconds;
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');

    return Column(
      spacing: 2,
      children: [
        Container(
          width: double.infinity,
          height: AppSizes.primaryButtonHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0F),
            borderRadius: BorderRadius.circular(AppSizes.buttonCornerRadius),
            border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
          ),
          child: Text(
            'Trial — $minutes:$seconds',
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: AppFonts.button,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrophySection() {
    if (_milestones.isEmpty) return const SizedBox();
    final topTwo = _milestones.take(2).toList();
    final curriculumDone = _state.curriculumCompletedCategories;
    final mastered = _state.masteredCategories;
    final earnedCount = topTwo.where((m) => _isEarned(m)).length;
    final totalEarned =
        earnedCount +
        (curriculumDone.isNotEmpty ? 1 : 0) +
        (mastered.isNotEmpty ? 1 : 0);
    String subtitle = totalEarned == 0
        ? 'Keep going — trophies are waiting.'
        : '$earnedCount of 2 earned';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8D5A0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              const Text(
                'My Trophies',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const Spacer(),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: topTwo.isNotEmpty
                    ? _buildTrophyCard(topTwo[0])
                    : const SizedBox(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: topTwo.length > 1
                    ? _buildTrophyCard(topTwo[1])
                    : const SizedBox(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMiniTrophyBox(
                  title: 'CURRICULUM',
                  earnedCategories: curriculumDone,
                  emptyIcon: '📖',
                  infoTitle: 'Curriculum Trophies',
                  infoMessage:
                      'Study each category to earn curriculum trophies. Studying increases your readiness score.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniTrophyBox(
                  title: 'MASTERED',
                  earnedCategories: mastered,
                  emptyIcon: '⭐',
                  infoTitle: 'Mastery Trophies',
                  infoMessage:
                      'Score 85% or higher on a category quiz to earn a mastery trophy.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildReadinessMeter()),
                const SizedBox(width: 10),
                Expanded(child: _buildReadinessMarquee()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterSection() {
    final state = _state;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        spacing: 2,
        children: [
          if (state.canUpgradeToLifetime) ...[
            GestureDetector(
              onTap: () async {
                final result = await IAPService.instance.buyUpgrade();
                if (result != IAPResult.initiated && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result.userMessage ?? 'Something went wrong.',
                      ),
                    ),
                  );
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1F00),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF0C575)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Text(
                      'Upgrade to Lifetime — ${IAPService.instance.upgradePrice}',
                      style: const TextStyle(
                        color: Color(0xFFF0C575),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (state.isLifetime)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '⭐ SafePrep™ Lifetime Member',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFF0C575),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (state.isTimeLimited && state.daysRemaining != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${state.daysRemaining} day${state.daysRemaining == 1 ? '' : 's'} of access remaining',
                style: TextStyle(
                  fontSize: 11,
                  color: state.daysRemaining! <= 2
                      ? Colors.redAccent
                      : AppColors.subtleText,
                ),
                textAlign: TextAlign.center,
              ),
            ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Padding(
          padding: AppSizes.pageMargin,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
              Container(
                height: 32,
                margin: const EdgeInsets.only(bottom: 8),
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
                  child: _currentFact.isEmpty
                      ? const SizedBox()
                      : Marquee(text: _currentFact),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    spacing: AppSizes.cardSpacing,
                    children: [
                      // Top slot: trial countdown (unpurchased) OR
                      // curriculum/assessment button (purchased).
                      _state.hasUnlockedApp
                          ? Column(
                              spacing: 2,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: AppSizes.primaryButtonHeight,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      MixpanelService.instance.track(
                                        'curriculum_tapped',
                                        properties: {'app_name': 'SP'},
                                      );
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AssessmentInfoPage(),
                                        ),
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
                                    child: const Text(
                                      'Create my personalized curriculum',
                                      style: TextStyle(
                                        fontSize: AppFonts.button,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  'Study less — take the assessment first',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.subtleText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            )
                          : _buildTrialCountdown(),

                      // Dashboard button
                      Column(
                        spacing: 2,
                        children: [
                          _buildButton(
                            'The SafePrep™ Dashboard',
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DashboardPage(),
                              ),
                            ),
                          ),
                          Text(
                            'Access your study curriculum and view progress',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.subtleText,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),

                      // Final exam button — hidden entirely when locked,
                      // rather than shown grayed out. Reappears automatically
                      // for paid users, or trial users who reach 100% readiness.
                      Builder(
                        builder: (context) {
                          final isLocked =
                              !_state.hasUnlockedApp &&
                              _state.readinessScore < 100;
                          if (isLocked) return const SizedBox();
                          return Column(
                            spacing: 2,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: AppSizes.primaryButtonHeight,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const FinalExamIntroPage(),
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
                                  child: const Text(
                                    'When ready — take the SafePrep exam',
                                    style: TextStyle(fontSize: AppFonts.button),
                                  ),
                                ),
                              ),
                              Text(
                                'Access enabled when 100% ServSafe readiness is achieved',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.success,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      _buildButton(
                        'Settings and information',
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsPage(),
                          ),
                        ),
                      ),

                      // Peace of Mind button
                      Column(
                        spacing: 2,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: AppSizes.primaryButtonHeight,
                            child: ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PeaceOfMindPage(),
                                ),
                              ).then((_) => setState(() {})),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryButton,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.buttonCornerRadius,
                                  ),
                                ),
                              ),
                              child: const Text(
                                '🔓 60 Second Trainers',
                                style: TextStyle(
                                  fontSize: AppFonts.button,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            'Quick tools to sharpen your knowledge',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.subtleText,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),

                      Row(
                        spacing: 8,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: AppSizes.primaryButtonHeight,
                              child: ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const SixtySecondRefreshPage(),
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
                                child: const Text(
                                  '⏱ 60-Second Refresh',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: SizedBox(
                              height: AppSizes.primaryButtonHeight,
                              child: ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AboutProctorsPage(),
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
                                child: const Text(
                                  '👤 About Proctors',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      _buildTrialUnlockBanner(),
                      _buildTrophySection(),
                      _buildFooterSection(),
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

class ReadinessMarqueeScroller extends StatefulWidget {
  final String text;
  final Color color;
  const ReadinessMarqueeScroller({
    super.key,
    required this.text,
    this.color = const Color(0xFF4A3728),
  });

  @override
  State<ReadinessMarqueeScroller> createState() =>
      _ReadinessMarqueeScrollerState();
}

class _ReadinessMarqueeScrollerState extends State<ReadinessMarqueeScroller> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    await Future.delayed(const Duration(seconds: 2));
    while (mounted) {
      if (!_scrollController.hasClients) {
        await Future.delayed(const Duration(milliseconds: 200));
        continue;
      }
      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }
      await _scrollController.animateTo(
        max,
        duration: Duration(milliseconds: (max * 25).toInt().clamp(3000, 20000)),
        curve: Curves.linear,
      );
      if (!mounted) break;
      _scrollController.jumpTo(0);
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repeated = '${widget.text}          ${widget.text}';
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          repeated,
          style: TextStyle(fontSize: 11, color: widget.color),
        ),
      ),
    );
  }
}

class Marquee extends StatefulWidget {
  final String text;
  const Marquee({super.key, required this.text});

  @override
  State<Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<Marquee> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    await Future.delayed(const Duration(seconds: 2));
    while (mounted) {
      if (!_scrollController.hasClients) {
        await Future.delayed(const Duration(milliseconds: 200));
        continue;
      }
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 0) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }
      await _scrollController.animateTo(
        maxExtent,
        duration: const Duration(seconds: 800),
        curve: Curves.linear,
      );
      if (!mounted) break;
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          widget.text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF4A3728)),
        ),
      ),
    );
  }
}
