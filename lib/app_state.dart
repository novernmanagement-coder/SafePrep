enum TestType { diagnostic, finalExam }

// ── Purchase type ─────────────────────────────────────────────
enum PurchaseType { none, sevenDay, fourteenDay, lifetime }

class TestResult {
  final DateTime timestamp;
  final TestType type;
  final int overallScore;
  final Map<String, int> categoryScores;
  final List<String> missedQuestionIds;

  TestResult({
    required this.timestamp,
    required this.type,
    required this.overallScore,
    required this.categoryScores,
    required this.missedQuestionIds,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'overallScore': overallScore,
    'categoryScores': categoryScores,
    'missedQuestionIds': missedQuestionIds,
  };

  factory TestResult.fromJson(Map<String, dynamic> json) => TestResult(
    timestamp: DateTime.parse(json['timestamp']),
    type: TestType.values.firstWhere((e) => e.name == json['type']),
    overallScore: json['overallScore'],
    categoryScores: Map<String, int>.from(json['categoryScores']),
    missedQuestionIds: List<String>.from(json['missedQuestionIds']),
  );
}

class SubcategoryGap {
  final String category;
  final String subcategory;
  int questionsAsked;
  int questionsCorrect;

  SubcategoryGap({
    required this.category,
    required this.subcategory,
    this.questionsAsked = 0,
    this.questionsCorrect = 0,
  });

  int get scorePercent =>
      questionsAsked == 0 ? 0 : (questionsCorrect * 100) ~/ questionsAsked;
}

class ConceptProgress {
  final String category;
  bool seen;

  ConceptProgress({required this.category, this.seen = false});

  Map<String, dynamic> toJson() => {'category': category, 'seen': seen};

  factory ConceptProgress.fromJson(Map<String, dynamic> json) =>
      ConceptProgress(category: json['category'], seen: json['seen']);
}

class AppState {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  // User
  String userName = '';
  bool hasSeenIntro = false;

  // ── Purchases ─────────────────────────────────────────────
  bool hasUnlockedApp = false;
  PurchaseType purchaseType = PurchaseType.none;
  DateTime? purchaseDate;

  bool get hasFullAccess => hasUnlockedApp;
  bool get hasUpgraded => hasUnlockedApp;
  bool get isLifetime => purchaseType == PurchaseType.lifetime;
  bool get isTimeLimited =>
      purchaseType == PurchaseType.sevenDay ||
      purchaseType == PurchaseType.fourteenDay;
  bool get canUpgradeToLifetime => isTimeLimited && hasUnlockedApp;

  bool get isExpired {
    if (!isTimeLimited || purchaseDate == null) return false;
    final days = purchaseType == PurchaseType.sevenDay ? 7 : 14;
    final expiry = purchaseDate!.add(Duration(days: days));
    return DateTime.now().isAfter(expiry);
  }

  int? get daysRemaining {
    if (!isTimeLimited || purchaseDate == null) return null;
    final days = purchaseType == PurchaseType.sevenDay ? 7 : 14;
    final expiry = purchaseDate!.add(Duration(days: days));
    final remaining = expiry.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }
  // ──────────────────────────────────────────────────────────

  // ── Readiness Index ───────────────────────────────────────
  int readinessScore = 0;
  String readinessCoachMessage =
      'Take the diagnostic assessment to start building your readiness score.';
  String readinessCheerMessage =
      'SafePrep was built for one purpose — to get you ready. Let\'s get started.';
  double extraCreditPoints = 0.0;
  int? finalExamScore;
  // ──────────────────────────────────────────────────────────

  // Test History
  List<TestResult> testHistory = [];

  // Category Scores
  Map<String, int> categoryQuizScores = {};
  Map<String, int> categoryBaselineScores = {};
  Map<String, int> categoryQuizAttempts = {};

  // Milestones & Trophies
  List<String> earnedMilestones = [];
  Set<String> earnedTrophyIds = {};
  int perfectCategoryCount = 0;

  // Missed questions
  List<String> missedFinalExamQuestionIds = [];

  // Study Progress
  List<String> studiedCategories = [];
  Map<String, int> curriculumProgress = {};
  int studyStreak = 0;
  DateTime? lastLaunchDate;

  // Concept Progress
  Map<int, ConceptProgress> conceptProgressRecords = {};

  // Subcategory Gaps
  Map<String, List<SubcategoryGap>> subcategoryGaps = {};

  // Constants
  static const int masteryThreshold = 85;
  static const int minAnswersForRawScores = 30;

  static const List<String> allCategories = [
    'Time & Temperature',
    'Cross-Contamination',
    'Food Preparation',
    'Receiving & Storage',
    'Personal Hygiene',
    'Cleaning & Sanitizing',
    'Facility & Equipment',
    'Food Safety Management',
  ];

  static const Map<String, int> servSafeIndustryBaseline = {
    'Time & Temperature': 52,
    'Cross-Contamination': 58,
    'Food Preparation': 55,
    'Receiving & Storage': 64,
    'Personal Hygiene': 71,
    'Cleaning & Sanitizing': 49,
    'Facility & Equipment': 68,
    'Food Safety Management': 57,
    'Pest Management': 72,
  };

  static const Map<String, double> categoryExamWeights = {
    'Time & Temperature': 0.23,
    'Cross-Contamination': 0.15,
    'Receiving & Storage': 0.15,
    'Personal Hygiene': 0.14,
    'Cleaning & Sanitizing': 0.12,
    'Food Preparation': 0.12,
    'Food Safety Management': 0.05,
    'Facility & Equipment': 0.02,
    'Pest Management': 0.02,
  };

  static const Map<String, int> categoryMaxQuestions = {
    'Time & Temperature': 9,
    'Cross-Contamination': 6,
    'Receiving & Storage': 6,
    'Personal Hygiene': 5,
    'Cleaning & Sanitizing': 5,
    'Food Preparation': 5,
    'Food Safety Management': 2,
    'Facility & Equipment': 1,
    'Pest Management': 1,
  };

  // Convenience getters
  bool get isNewUser => userName.isEmpty;
  bool get hasTakenAssessment =>
      testHistory.isNotEmpty || categoryQuizScores.isNotEmpty;

  TestResult? get latestResult {
    if (testHistory.isEmpty) return null;
    return testHistory.reduce(
      (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b,
    );
  }

  TestResult? get baselineResult {
    if (testHistory.isEmpty) return null;
    return testHistory.reduce(
      (a, b) => a.timestamp.isBefore(b.timestamp) ? a : b,
    );
  }

  List<String> get masteredCategories => allCategories
      .where(
        (c) =>
            hasScoreForCategory(c) && getCategoryScore(c) >= masteryThreshold,
      )
      .toList();

  List<String> get studyCategories =>
      allCategories.where((c) => !masteredCategories.contains(c)).toList()
        ..sort((a, b) => getCategoryScore(a).compareTo(getCategoryScore(b)));

  // Methods
  void addEarnedMilestone(String triggerId, String milestoneMessage) {
    earnedTrophyIds.add(triggerId);
    earnedMilestones.insert(0, milestoneMessage);
    if (earnedMilestones.length > 5) earnedMilestones.removeAt(5);
  }

  void incrementCategoryQuizAttempts(String category) {
    categoryQuizAttempts[category] = (categoryQuizAttempts[category] ?? 0) + 1;
  }

  int getCategoryQuizAttempts(String category) =>
      categoryQuizAttempts[category] ?? 0;

  void saveCategoryQuizScore(String category, int percent) {
    categoryQuizScores[category] = percent;
    categoryBaselineScores.putIfAbsent(category, () => percent);
  }

  int getCategoryScore(String category) {
    if (categoryQuizScores.containsKey(category)) {
      return categoryQuizScores[category]!;
    }
    final latest = latestResult;
    if (latest != null && latest.categoryScores.containsKey(category)) {
      return latest.categoryScores[category]!;
    }
    return 0;
  }

  bool hasScoreForCategory(String category) =>
      categoryQuizScores.containsKey(category) ||
      (latestResult?.categoryScores.containsKey(category) ?? false);

  int getOverallScore() {
    if (latestResult != null) return latestResult!.overallScore;
    if (categoryQuizScores.isNotEmpty) {
      return categoryQuizScores.values.reduce((a, b) => a + b) ~/
          categoryQuizScores.length;
    }
    return 0;
  }

  int getBaselineScore(String category) {
    final baseline = baselineResult;
    if (baseline != null && baseline.categoryScores.containsKey(category)) {
      return baseline.categoryScores[category]!;
    }
    if (categoryBaselineScores.containsKey(category)) {
      return categoryBaselineScores[category]!;
    }
    return servSafeIndustryBaseline[category] ?? 60;
  }

  int getBlendedScore(String category, {required int totalAnswered}) {
    final baseline = servSafeIndustryBaseline[category] ?? 60;
    if (totalAnswered == 0) return baseline;
    if (!hasScoreForCategory(category)) return baseline;
    final rawScore = getCategoryScore(category);
    if (rawScore == 0 && !categoryQuizScores.containsKey(category)) {
      return baseline;
    }
    if (totalAnswered >= minAnswersForRawScores) return rawScore;
    final totalAssessmentQ = categoryMaxQuestions.values.fold(
      0,
      (sum, v) => sum + v,
    );
    final answeredFraction = (totalAnswered / totalAssessmentQ).clamp(0.0, 1.0);
    final examWeight = categoryExamWeights[category] ?? 0.10;
    final maxBoost = examWeight * (rawScore - baseline);
    return (baseline + (maxBoost * answeredFraction)).round();
  }

  int getBlendedOverallScore({required int totalAnswered}) {
    final scores = allCategories
        .map((c) => getBlendedScore(c, totalAnswered: totalAnswered))
        .toList();
    return scores.reduce((a, b) => a + b) ~/ scores.length;
  }

  bool hasStudiedCategory(String category) =>
      studiedCategories.any((c) => c.toLowerCase() == category.toLowerCase());

  int getCurriculumProgress(String category) =>
      curriculumProgress[category] ?? 0;

  bool isMastered(String category) => masteredCategories.contains(category);

  void markCategoryStudied(String category) {
    if (!hasStudiedCategory(category)) studiedCategories.add(category);
  }

  void markConceptReviewed(String category) {
    curriculumProgress[category] = (curriculumProgress[category] ?? 0) + 1;
  }

  void clearCurriculumProgress() {
    // Only clear studied/curriculum tracking for categories that DON'T
    // have a real quiz score. If a category was studied AND scored during
    // trial, that's genuine, earned progress — it survives purchase intact,
    // including its CURRICULUM trophy. Only incomplete/browsing-only state
    // gets reset, so purchasing never erases work the user actually did.
    studiedCategories.removeWhere((c) => !hasScoreForCategory(c));
    curriculumProgress.removeWhere((c, _) => !hasScoreForCategory(c));
  }

  int getOverallCurriculumPercent() {
    final total = allCategories.length;
    if (total == 0) return 0;
    final mastered = masteredCategories;
    final studiedOnly = studiedCategories
        .where((c) => !mastered.contains(c))
        .length;
    final weighted = (mastered.length * 100) + (studiedOnly * 50);
    return weighted ~/ total;
  }

  bool isCurriculumCompleteForCategory(String category) {
    return hasStudiedCategory(category) && hasScoreForCategory(category);
  }

  List<String> get curriculumCompletedCategories =>
      allCategories.where((c) => isCurriculumCompleteForCategory(c)).toList();

  void updateStreak() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    if (lastLaunchDate == null) {
      studyStreak = 1;
      lastLaunchDate = todayDate;
      return;
    }
    final last = DateTime(
      lastLaunchDate!.year,
      lastLaunchDate!.month,
      lastLaunchDate!.day,
    );
    if (last == todayDate) {
      return;
    } else if (last == todayDate.subtract(const Duration(days: 1))) {
      studyStreak++;
      lastLaunchDate = todayDate;
    } else {
      studyStreak = 1;
      lastLaunchDate = todayDate;
    }
  }

  void reset() {
    final savedHasUnlocked = hasUnlockedApp;
    final savedPurchaseType = purchaseType;
    final savedPurchaseDate = purchaseDate;

    userName = '';
    hasSeenIntro = false;
    hasUnlockedApp = false;
    purchaseType = PurchaseType.none;
    purchaseDate = null;
    readinessScore = 0;
    readinessCoachMessage =
        'Take the diagnostic assessment to start building your readiness score.';
    readinessCheerMessage =
        'SafePrep was built for one purpose — to get you ready. Let\'s get started.';
    extraCreditPoints = 0.0;
    finalExamScore = null;
    testHistory.clear();
    subcategoryGaps.clear();
    studiedCategories.clear();
    curriculumProgress.clear();
    categoryQuizScores.clear();
    categoryBaselineScores.clear();
    categoryQuizAttempts.clear();
    missedFinalExamQuestionIds.clear();
    earnedMilestones.clear();
    earnedTrophyIds.clear();
    perfectCategoryCount = 0;
    conceptProgressRecords.clear();
    studyStreak = 0;
    lastLaunchDate = null;

    hasUnlockedApp = savedHasUnlocked;
    purchaseType = savedPurchaseType;
    purchaseDate = savedPurchaseDate;
  }

  Map<String, dynamic> toJson() => {
    'stateVersion': 2,
    'userName': userName,
    'hasSeenIntro': hasSeenIntro,
    'hasUnlockedApp': hasUnlockedApp,
    'purchaseType': purchaseType.name,
    'purchaseDate': purchaseDate?.toIso8601String(),
    'readinessScore': readinessScore,
    'readinessCoachMessage': readinessCoachMessage,
    'readinessCheerMessage': readinessCheerMessage,
    'extraCreditPoints': extraCreditPoints,
    'finalExamScore': finalExamScore,
    'testHistory': testHistory.map((t) => t.toJson()).toList(),
    'categoryQuizScores': categoryQuizScores,
    'categoryBaselineScores': categoryBaselineScores,
    'categoryQuizAttempts': categoryQuizAttempts,
    'earnedMilestones': earnedMilestones,
    'earnedTrophyIds': earnedTrophyIds.toList(),
    'perfectCategoryCount': perfectCategoryCount,
    'missedFinalExamQuestionIds': missedFinalExamQuestionIds,
    'studiedCategories': studiedCategories,
    'curriculumProgress': curriculumProgress,
    'studyStreak': studyStreak,
    'lastLaunchDate': lastLaunchDate?.toIso8601String(),
    'conceptProgressRecords': conceptProgressRecords.map(
      (k, v) => MapEntry(k.toString(), v.toJson()),
    ),
  };

  void fromJson(Map<String, dynamic> json) {
    final version = json['stateVersion'] ?? 1;
    if (version < 2) {
      studiedCategories.clear();
    }

    userName = json['userName'] ?? '';
    hasSeenIntro = json['hasSeenIntro'] ?? false;
    hasUnlockedApp = json['hasUnlockedApp'] ?? false;
    purchaseType = PurchaseType.values.firstWhere(
      (e) => e.name == (json['purchaseType'] ?? 'none'),
      orElse: () => PurchaseType.none,
    );
    if (hasUnlockedApp && purchaseType == PurchaseType.none) {
      purchaseType = PurchaseType.lifetime;
    }
    purchaseDate = json['purchaseDate'] != null
        ? DateTime.parse(json['purchaseDate'])
        : null;
    readinessScore = json['readinessScore'] ?? 0;
    readinessCoachMessage =
        json['readinessCoachMessage'] ??
        'Take the diagnostic assessment to start building your readiness score.';
    readinessCheerMessage =
        json['readinessCheerMessage'] ??
        'SafePrep was built for one purpose — to get you ready. Let\'s get started.';
    extraCreditPoints = (json['extraCreditPoints'] ?? 0.0).toDouble();
    finalExamScore = json['finalExamScore'];
    testHistory = (json['testHistory'] as List? ?? [])
        .map((t) => TestResult.fromJson(t))
        .toList();
    categoryQuizScores = Map<String, int>.from(
      json['categoryQuizScores'] ?? {},
    );
    categoryBaselineScores = Map<String, int>.from(
      json['categoryBaselineScores'] ?? {},
    );
    categoryQuizAttempts = Map<String, int>.from(
      json['categoryQuizAttempts'] ?? {},
    );
    earnedMilestones = List<String>.from(json['earnedMilestones'] ?? []);
    earnedTrophyIds = Set<String>.from(json['earnedTrophyIds'] ?? []);
    perfectCategoryCount = json['perfectCategoryCount'] ?? 0;
    missedFinalExamQuestionIds = List<String>.from(
      json['missedFinalExamQuestionIds'] ?? [],
    );
    studiedCategories = version >= 2
        ? List<String>.from(json['studiedCategories'] ?? [])
        : studiedCategories;
    curriculumProgress = Map<String, int>.from(
      json['curriculumProgress'] ?? {},
    );
    studyStreak = json['studyStreak'] ?? 0;
    lastLaunchDate = json['lastLaunchDate'] != null
        ? DateTime.parse(json['lastLaunchDate'])
        : null;
    conceptProgressRecords = (json['conceptProgressRecords'] as Map? ?? {}).map(
      (k, v) => MapEntry(int.parse(k), ConceptProgress.fromJson(v)),
    );
  }
}
