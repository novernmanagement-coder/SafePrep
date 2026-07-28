/// The locked 10-question onboarding diagnostic.
///
/// ORDER IS DELIBERATE — DO NOT RANDOMIZE. Easy questions first, then
/// partial-knowledge traps, then two expected misses. That sequence
/// produces a build-up-then-collapse arc: the first four come back green
/// ("I've got this"), red starts appearing around Q5, and by Q9-10 the
/// user has watched their own confidence come apart. Shuffling flattens
/// that into noise.
///
/// Calibrated for 4-6 correct out of 10. Refreshers land 6-8, newbies
/// with some study land 4-6.
///
/// Every question is exam-tested material. No FDA-code trivia, no
/// regulatory citations, nothing that exists only to make someone feel
/// unprepared — that's the competitor's business model, not ours. If it
/// isn't on the test, it isn't in here.
///
/// NOTE: nine of these are verbatim from Assets/FinalTestQuestions5.csv.
/// Q8 (exclude vs restrict) is hand-written — no exclude/restrict question
/// exists in the bank, which is a real content gap worth filling
/// separately. Hardcoding the set here is intentional: this is a fixed
/// marketing sequence, and it must not drift when the CSV changes.
library;

class DiagnosticQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;

  /// Feeds the per-category gap map on the results screen.
  final String category;

  /// Shown only when StudyStyle.explanations is selected.
  final String explanation;

  const DiagnosticQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.category,
    required this.explanation,
  });
}

const List<DiagnosticQuestion> kDiagnosticQuestions = [
  // ── Easy (banks their correct column) ─────────────────────────────
  DiagnosticQuestion(
    question: 'What is the temperature danger zone?',
    options: [
      '32\u00B0F \u2013 100\u00B0F',
      '40\u00B0F \u2013 140\u00B0F',
      '41\u00B0F \u2013 135\u00B0F',
      '45\u00B0F \u2013 130\u00B0F',
    ],
    correctIndex: 2,
    category: 'Food Safety Foundations',
    explanation:
        'Pathogens grow fastest between 41\u00B0F and 135\u00B0F. The old '
        '40\u2013140 range is a common misremembering.',
  ),
  DiagnosticQuestion(
    question: 'What is the minimum internal cooking temperature for poultry?',
    options: [
      '165\u00B0F for 15 seconds',
      '155\u00B0F for 15 seconds',
      '150\u00B0F for 15 seconds',
      '145\u00B0F for 15 seconds',
    ],
    correctIndex: 0,
    category: 'Time & Temperature',
    explanation:
        'Poultry is the highest cook temperature on the exam \u2014 '
        '165\u00B0F for 15 seconds, every time.',
  ),
  DiagnosticQuestion(
    question:
        'You are holding cold food without temperature control. What must '
        'be done?',
    options: [
      'Keep it covered at all times',
      'Label it with the time it must be discarded',
      'Stir it once every hour',
      'Add fresh ice every two hours',
    ],
    correctIndex: 1,
    category: 'Time & Temperature',
    explanation:
        'Time as a public health control requires a discard time marked on '
        'the food. Without the label, the clock cannot be verified.',
  ),
  DiagnosticQuestion(
    question: 'How long should hands be scrubbed during proper handwashing?',
    options: [
      '30 to 60 seconds',
      '20 to 30 seconds',
      '10 to 15 seconds',
      '5 to 8 seconds',
    ],
    correctIndex: 2,
    category: 'Personal Hygiene',
    explanation:
        'The scrub itself is 10\u201315 seconds. The whole process runs '
        'about 20 seconds \u2014 the two numbers get confused constantly.',
  ),

  // ── Mid (partial-knowledge traps) ─────────────────────────────────
  DiagnosticQuestion(
    question:
        'What is the minimum internal cooking temperature for stuffed meat?',
    options: [
      '145\u00B0F for 15 seconds',
      '155\u00B0F for 15 seconds',
      '165\u00B0F for 15 seconds',
      '150\u00B0F for 15 seconds',
    ],
    correctIndex: 2,
    category: 'Time & Temperature',
    explanation:
        'Stuffing insulates the meat, so anything stuffed goes to '
        '165\u00B0F regardless of the cut. Reasoning from the meat type '
        'alone gets this one wrong.',
  ),
  DiagnosticQuestion(
    question:
        'Cooked food must cool from 135\u00B0F to 70\u00B0F within how long?',
    options: ['1 hour', '2 hours', '3 hours', '4 hours'],
    correctIndex: 1,
    category: 'Time & Temperature',
    explanation:
        'Two hours for the first stage, then four more to reach '
        '41\u00B0F \u2014 six hours total. The first stage is the one '
        'people miss.',
  ),
  DiagnosticQuestion(
    question:
        'What is the correct concentration range for a chlorine sanitizer '
        'solution?',
    options: [
      '50 \u2013 99 ppm',
      '200 \u2013 300 ppm',
      '10 \u2013 20 ppm',
      '150 \u2013 200 ppm',
    ],
    correctIndex: 0,
    category: 'Cleaning & Sanitizing',
    explanation:
        '200\u2013300 ppm is the quat range. Chlorine works far lower, and '
        'too strong is a chemical hazard rather than extra safety.',
  ),
  DiagnosticQuestion(
    question:
        'A food handler has a sore throat with fever. Your operation '
        'serves a nursing home. What must you do?',
    options: [
      'Restrict them from working with food',
      'Exclude them from the operation',
      'Restrict them until the fever passes',
      'Allow them to work wearing a mask and gloves',
    ],
    correctIndex: 1,
    category: 'Personal Hygiene',
    explanation:
        'Sore throat with fever normally means restrict. Serving a '
        'high-risk population flips it to exclude \u2014 that detail is '
        'the whole question.',
  ),

  // ── Hard (expected misses) ────────────────────────────────────────
  DiagnosticQuestion(
    question: 'What is the correct top-to-bottom storage order in a cooler?',
    options: [
      'Whole cuts, seafood, ground meat, ready-to-eat, poultry',
      'Ready-to-eat, seafood, whole cuts, ground meat, poultry',
      'Ground meat, poultry, whole cuts, seafood, ready-to-eat',
      'Seafood, whole cuts, ground meat, poultry, ready-to-eat',
    ],
    correctIndex: 1,
    category: 'Cross-Contamination',
    explanation:
        'Order follows cooking temperature \u2014 lowest on top, highest '
        'on the bottom. Ready-to-eat never sits below raw product.',
  ),
  DiagnosticQuestion(
    question:
        'How long must shellfish tags be kept on file after the last '
        'shellfish from that container is sold?',
    options: ['7 days', '30 days', '90 days', '1 year'],
    correctIndex: 2,
    category: 'Receiving & Storage',
    explanation:
        '90 days. The tag is the trace-back record if anyone gets sick, '
        'which is why the retention window is that long.',
  ),
];

// ─────────────────────────────────────────────────────────────────────
// Confidence-weighted scoring
// ─────────────────────────────────────────────────────────────────────
//
// After each answer the user taps a 1–5 star confidence rating. The
// scoring matrix rewards calibrated self-knowledge and punishes
// overconfidence — a 5-star wrong is the worst possible outcome and the
// moment that sells the app.
//
//   Stars │ Correct │ Wrong
//   ──────┼─────────┼──────
//     5   │   10    │   0
//     4   │    8    │   1
//     3   │    6    │   2
//     2   │    4    │   3
//     1   │    2    │   4
//
// Max possible: 100. The resulting percentage is uncomputable in the
// user's head, grounded in data they supplied, and meaningfully
// different from raw accuracy.

/// Points earned for a single question given correctness and star rating.
int confidencePoints(bool correct, int stars) {
  assert(stars >= 1 && stars <= 5);
  if (correct) {
    // 5→10, 4→8, 3→6, 2→4, 1→2
    return stars * 2;
  } else {
    // 5→0, 4→1, 3→2, 2→3, 1→4
    return 5 - stars;
  }
}

/// Scored outcome of the diagnostic, built from the answer list.
///
/// Holds both the boolean correct/incorrect record (for category gap
/// mapping) and the per-question confidence stars (for the weighted
/// readiness score). The two are parallel lists, same length, same order.
class DiagnosticResult {
  /// One entry per question, in order — true if answered correctly.
  final List<bool> answers;

  /// One entry per question — the user's self-rated confidence, 1–5 stars.
  /// If the diagnostic was taken without the confidence capture (shouldn't
  /// happen in the onboarding flow, but defensive), defaults to 3 for
  /// every question so the score degrades to a neutral weighting rather
  /// than crashing.
  final List<int> confidence;

  const DiagnosticResult(this.answers, {this.confidence = const []});

  int get correct => answers.where((a) => a).length;
  int get total => answers.length;

  /// Confidence list, padded to match answers if needed.
  List<int> get _conf {
    if (confidence.length >= answers.length) return confidence;
    return [
      ...confidence,
      for (var i = confidence.length; i < answers.length; i++) 3,
    ];
  }

  /// Confidence-weighted score, 0–100.
  ///
  /// This is the number that fills the ring. It factors in how sure the
  /// user was alongside whether they were right, so it captures something
  /// a straight percentage doesn't — and it can't be reverse-engineered
  /// from a mental tally of correct answers.
  int get weightedScore {
    if (total == 0) return 0;
    final conf = _conf;
    int sum = 0;
    for (var i = 0; i < answers.length; i++) {
      sum += confidencePoints(answers[i], conf[i]);
    }
    // Max possible = total * 10 (every question correct at 5 stars).
    return ((sum / (total * 10)) * 100).round();
  }

  /// Anxiety gate.
  ///
  /// The stars are not a measurement to be corrected for — they are the
  /// user telling us how they feel. A rating of 3 or below is a hedge:
  /// guessing, nervous, or not wanting to look cocky. Genuine confidence
  /// commits to a 4 or a 5. So if half or more of the answers came in at
  /// 3 stars or below, the user is telling us they don't feel ready — and
  /// that self-report is the headline, not the score.
  ///
  /// "Half or more" uses ceil: on 10 questions, exactly 5 low-confidence
  /// answers trips the gate.
  bool get lowConfidenceDominant {
    if (total == 0) return false;
    final conf = _conf;
    final lowCount = conf.where((s) => s <= 3).length;
    return lowCount >= (total / 2).ceil();
  }

  /// Final readiness verdict.
  ///
  /// Confidence is the primary gate. If the user is telling us they don't
  /// feel ready (see [lowConfidenceDominant]), they are not ready — no
  /// matter what the score says. Only once that clears does the weighted
  /// score decide it, against a 75% pass line. There is no raw-correct
  /// override: 8 right with low confidence is a not-ready, by design.
  bool get isReady {
    if (lowConfidenceDominant) return false;
    return weightedScore >= 75;
  }

  /// How well the user's confidence predicted their accuracy.
  ///
  /// Derived entirely from data they gave us — their star taps and their
  /// answers. Nothing invented, nothing that requires a baseline or a
  /// population comparison.
  ///
  /// - "overconfident": 2+ questions where they gave 4-5 stars and got
  ///   it wrong. This is the conversion signal — they think they know
  ///   more than they do.
  /// - "underconfident": 3+ questions where they gave 1-2 stars and got
  ///   it right. They know more than they think.
  /// - "well-calibrated": neither threshold met.
  String get calibrationLabel {
    final conf = _conf;
    int highConfWrong = 0;
    int lowConfRight = 0;

    for (var i = 0; i < answers.length; i++) {
      if (!answers[i] && conf[i] >= 4) highConfWrong++;
      if (answers[i] && conf[i] <= 2) lowConfRight++;
    }

    if (highConfWrong >= 2) return 'overconfident';
    if (lowConfRight >= 3) return 'underconfident';
    return 'well-calibrated';
  }

  /// Correct count per category.
  Map<String, int> get categoryCorrect {
    final map = <String, int>{};
    for (var i = 0; i < answers.length; i++) {
      final cat = kDiagnosticQuestions[i].category;
      map[cat] = (map[cat] ?? 0) + (answers[i] ? 1 : 0);
    }
    return map;
  }

  /// Questions asked per category.
  Map<String, int> get categoryTotal {
    final map = <String, int>{};
    for (var i = 0; i < answers.length; i++) {
      final cat = kDiagnosticQuestions[i].category;
      map[cat] = (map[cat] ?? 0) + 1;
    }
    return map;
  }

  /// Confidence-weighted score per category, 0–100.
  ///
  /// With 1-2 questions per category, raw correct/incorrect can only
  /// produce 0%, 50%, or 100%. The confidence stars fix this: each
  /// question contributes 0–10 points, so a 2-question category has
  /// 21 possible values (0–20 = 0%–100% in 5% increments). Honest
  /// granularity from data the user supplied.
  Map<String, int> get categoryWeightedScore {
    final conf = _conf;
    final scores = <String, int>{};
    final maxes = <String, int>{};

    for (var i = 0; i < answers.length; i++) {
      final cat = kDiagnosticQuestions[i].category;
      scores[cat] = (scores[cat] ?? 0) + confidencePoints(answers[i], conf[i]);
      maxes[cat] = (maxes[cat] ?? 0) + 10;
    }

    return {
      for (final cat in scores.keys)
        cat: ((scores[cat]! / maxes[cat]!) * 100).round(),
    };
  }

  /// Qualitative label per category — Strong / Shaky / Gap.
  /// Keyed off the weighted score so it reflects confidence, not just
  /// raw accuracy.
  Map<String, String> get categoryLabel {
    final scores = categoryWeightedScore;
    return {
      for (final cat in scores.keys)
        cat: scores[cat]! >= 70
            ? 'Strong'
            : scores[cat]! >= 40
            ? 'Shaky'
            : 'Gap',
    };
  }

  /// Categories with at least one miss, worst first. Drives the "start
  /// here" recommendation and the three free trainer categories.
  /// Now sorted by weighted score rather than raw ratio.
  List<String> get weakestCategories {
    final scores = categoryWeightedScore;
    final totalMap = categoryTotal;
    final correctMap = categoryCorrect;
    final cats = totalMap.keys.where((c) {
      return (correctMap[c] ?? 0) < (totalMap[c] ?? 0);
    }).toList();
    cats.sort((a, b) {
      return (scores[a] ?? 0).compareTo(scores[b] ?? 0);
    });
    return cats;
  }
}
