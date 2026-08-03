/// Answers collected during the onboarding funnel.
///
/// Deliberately NOT persisted and NOT written into AppState — the
/// onboarding is a conversion flow, not a data source for the adaptive
/// engine. It populates nothing in the app; the real readiness meter and
/// study plan are built from in-app activity after purchase.
library;

/// How ready the user says they feel walking in. Self-reported,
/// captured on the knowledge-level screen. Flat, equal-weight options —
/// no tier/scope language — since there's only one product to buy, so
/// there's nothing to price-game toward. Drives paywall subline copy
/// and FSME's one-line reaction only; does NOT change the underlying
/// curriculum, pacing, or which category starts first.
enum KnowledgeLevel {
  confident,
  prepared,
  almostReady,
  newToServSafe;

  String get tag {
    switch (this) {
      case KnowledgeLevel.confident:
        return 'confident';
      case KnowledgeLevel.prepared:
        return 'prepared';
      case KnowledgeLevel.almostReady:
        return 'almost_ready';
      case KnowledgeLevel.newToServSafe:
        return 'new_to_servsafe';
    }
  }
}

/// How far out the user's exam is. Captured on screen 4, used to pace the
/// plan and modulate the results copy.
///
/// [notScheduled] is also a proctoring lead — those users should be
/// pointed at the FSME Find a Proctor directory rather than urgency copy.
enum ExamWindow {
  oneToThree,
  fourToTen,
  tenPlus,
  notScheduled;

  /// Value sent to Mixpanel and carried through the funnel.
  String get tag {
    switch (this) {
      case ExamWindow.oneToThree:
        return '1-3_days';
      case ExamWindow.fourToTen:
        return '4-10_days';
      case ExamWindow.tenPlus:
        return '10+_days';
      case ExamWindow.notScheduled:
        return 'not_scheduled';
    }
  }

  /// Rough day count for the "X minutes a day" math on the results
  /// screen. Null when nothing is booked — no deadline, no pacing.
  int? get daysToExam {
    switch (this) {
      case ExamWindow.oneToThree:
        return 2;
      case ExamWindow.fourToTen:
        return 7;
      case ExamWindow.tenPlus:
        return 14;
      case ExamWindow.notScheduled:
        return null;
    }
  }
}

/// How the user wants questions presented. Chosen on screen 5.
///
/// Three genuinely distinct render modes:
///   [explanations] — correct answer green, wrong pick red, plus a
///                    per-question explanation.
///   [answersOnly]  — correct answer green, wrong pick red, no explanation.
///   [quizFormat]   — no feedback at all during the quiz; everything is
///                    revealed on the results screen.
enum StudyStyle {
  explanations,
  answersOnly,
  quizFormat;

  String get tag {
    switch (this) {
      case StudyStyle.explanations:
        return 'answers_and_explanations';
      case StudyStyle.answersOnly:
        return 'answers_only';
      case StudyStyle.quizFormat:
        return 'quiz_format';
    }
  }

  /// True when the diagnostic should mark answers as they're given.
  /// False for [quizFormat], where the results screen carries the whole
  /// emotional load on its own.
  bool get showsImmediateFeedback => this != StudyStyle.quizFormat;

  /// True only when a per-question explanation should appear.
  bool get showsExplanations => this == StudyStyle.explanations;
}

/// SharedPreferences key holding how many times the user has completed
/// onboarding (reached the paywall). Formerly incremented inside
/// OnboardReadiness on the diagnostic verdict screen; that screen is
/// gone in the self-report redesign, so OnboardPaywall increments this
/// now instead — reaching the paywall is the new equivalent of "ran the
/// funnel." Read by SplashPage to gate the free-attempts count. Same
/// string value preserved so existing installs' saved counts aren't
/// orphaned.
const String kOnboardingRunsKey = 'onboarding_runs_completed';

/// Free onboarding run-throughs before the splash requires the access
/// code.
const int kMaxFreeRuns = 2;

/// Funnel-scoped answer store. Lives for the duration of onboarding only.
class OnboardingAnswers {
  OnboardingAnswers._();
  static final OnboardingAnswers instance = OnboardingAnswers._();

  KnowledgeLevel? knowledgeLevel;
  ExamWindow? examWindow;
  StudyStyle? studyStyle;

  void reset() {
    knowledgeLevel = null;
    examWindow = null;
    studyStyle = null;
  }
}
