import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../app_state.dart';
import '../mixpanel_service.dart';
import '../iap_service.dart';
import '../fsme_popup.dart';
import '../fsme_post_purchase_landing.dart';
import '../redeem_code_service.dart';
import 'onboard_answers.dart';
import 'onboard_trust.dart';
import '../rapid_fire_limited_intro.dart';

/// Onboarding paywall — redesigned for the self-report funnel, then
/// redesigned again to add a personalized recap.
///
/// One product now ($4.99, 7 days full access) since the Refresher
/// tier has been eliminated entirely — there's nothing to price-game
/// toward, so the screen is a single clean ask rather than two priced
/// options.
///
/// The recap card confirms the user's own exam-date, study-style, and
/// content-preference answers back to them (read-only — no inline
/// editing; see [_recapCard] for why). FSME gets one reaction line
/// below it, keyed to the content-preference choice (Full Curriculum /
/// Hot Topics / Refresher) — copy only, never a different product or
/// different curriculum. There is no longer a knowledge-level/test-
/// history question anywhere in the funnel — it was cut entirely
/// (see [[safeprep-onboarding]]) since it was seen as a real drop-off
/// risk: people may not answer it truthfully, and there was no way to
/// tell. "Something not right? Start over" is the one correction path,
/// re-running the actual questions rather than letting people fix
/// answers in place here.
///
/// "Show me more first" routes to the Rapid Fire preview as a taste
/// of the tool before a second ask, rather than a hard decline exit.
///
/// On purchase success, routes to [FsmePostPurchaseLanding] — the
/// one-time FSME cluster tour — rather than the old terminal-style
/// build-sequence screen, since the self-report funnel has no
/// diagnostic data to build a "your plan is ready" sequence from.
class OnboardPaywall extends StatefulWidget {
  const OnboardPaywall({super.key});

  @override
  State<OnboardPaywall> createState() => _OnboardPaywallState();
}

class _OnboardPaywallState extends State<OnboardPaywall> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);

  static const String _price = '\$4.99';

  bool _purchasing = false;
  bool _restoring = false;
  bool _redeeming = false;

  /// FSME's reaction line, keyed to the content-preference choice
  /// from the Content Preference onboarding screen — a direct
  /// callback to what the user picked, reinforcing that choice right
  /// before the purchase ask.
  String _contentLineFor(ContentPreference? preference) {
    switch (preference) {
      case ContentPreference.fullCurriculum:
        return "Full Curriculum, nice — we've got 500+ questions, "
            'unlimited quizzes, and some fantastic 60-second trainers '
            'to keep it all top of mind.';
      case ContentPreference.hotTopics:
        return 'Hot Topics it is — study only what you need, we '
            "won't waste your time re-covering what you've already "
            'mastered.';
      case ContentPreference.refresher:
        return "Refresher, my friend? You've come to the right place "
            '— my 60-second trainers are exactly what you asked '
            'for, fast hits to reinforce what you already know.';
      case null:
        return "Whatever you're focused on, we've got the tools to "
            'back it up.';
    }
  }

  /// One read-only recap row on the paywall - confirms an answer back
  /// to the user, no interactivity. Deliberately not editable: an
  /// earlier draft let people tap to change answers right here, but
  /// that turned the paywall into a second round of decisions right
  /// before the purchase ask, which is exactly what this redesign is
  /// trying to remove. The one correction path is "Start over" below,
  /// which re-runs the actual questions instead.
  Widget _recapRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.12),
              border: Border.all(color: _gold.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, size: 12, color: _gold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 0.05,
                    color: _softWhite.withValues(alpha: 0.4),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _gold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The "we already did the work" reinforcement card. Pure
  /// confirmation of what the user already told the app on the exam-
  /// date, study-style, and content-preference screens.
  Widget _recapCard() {
    final examWindow = OnboardingAnswers.instance.examWindow;
    final studyStyle = OnboardingAnswers.instance.studyStyle;
    final contentPreference = OnboardingAnswers.instance.contentPreference;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _softWhite.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "WE'RE READY FOR YOU",
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              color: _softWhite.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 12),
          _recapRow(
            icon: Icons.schedule,
            label: 'YOUR EXAM',
            value: examWindow?.label ?? 'Not set',
          ),
          _recapRow(
            icon: Icons.star,
            label: 'STUDY BEST',
            value: studyStyle?.label ?? 'Not set',
          ),
          _recapRow(
            icon: Icons.explore,
            label: 'CONTENT',
            value: contentPreference?.label ?? 'Not set',
          ),
        ],
      ),
    );
  }

  /// Sole correction path for the recap card above - re-runs the
  /// exam-date/study-style/knowledge questions from the Trust screen
  /// rather than offering per-field inline editing on the paywall
  /// itself (rejected earlier as "too much for them to decide on"
  /// right before the purchase ask).
  void _startOver() {
    MixpanelService.instance.track(
      'SpOn_Pay_StartOver',
      properties: {'app_name': 'SP'},
    );
    OnboardingAnswers.instance.reset();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnboardTrust()),
      (_) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    MixpanelService.instance.track(
      'SpOn_Pay_Viewed',
      properties: {
        'app_name': 'SP',
        'content_preference':
            OnboardingAnswers.instance.contentPreference?.tag ?? 'unknown',
      },
    );
    _recordOnboardingRun();
  }

  /// Reaching the paywall counts as one completed onboarding run — the
  /// splash uses the tally to cap free runs before requiring the access
  /// code. Formerly incremented in OnboardReadiness, which no longer
  /// exists in the self-report redesign. See kOnboardingRunsKey.
  Future<void> _recordOnboardingRun() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(kOnboardingRunsKey) ?? 0;
    await prefs.setInt(kOnboardingRunsKey, current + 1);
  }

  Future<void> _purchase() async {
    if (_purchasing) return;
    setState(() => _purchasing = true);

    MixpanelService.instance.track(
      'SpOn_Purchase',
      properties: {
        'app_name': 'SP',
        'source': 'paywall',
        'price': _price,
        'content_preference':
            OnboardingAnswers.instance.contentPreference?.tag ?? 'unknown',
      },
    );

    final result = await IAPService.instance.buySevenDay();

    if (!mounted) return;
    setState(() => _purchasing = false);

    if (result == IAPResult.success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const FsmePostPurchaseLanding()),
        (_) => false,
      );
    } else if (result != IAPResult.canceled) {
      final message = result.userMessage;
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 12),
          ),
        );
      }
    }
  }

  // Recovery path for the Play Billing "already owned" scenario: a
  // purchase that charged the user's card and is already recorded as
  // owned on the store's side, but whose success never got processed
  // locally (e.g. the app was killed between the purchase completing
  // and AppStatePersistence.save() writing to disk, or a transient
  // stream error). Buying again just returns "item already owned"
  // from the store with no way forward, so this is the only escape
  // hatch for someone in that state — always visible, not just shown
  // after an error, since Apple/Play guidelines expect a restore
  // option to be discoverable up front, and the person in this state
  // never sees a purchase error on THIS attempt to know to look for one.
  Future<void> _restorePurchases() async {
    if (_restoring || _purchasing) return;
    setState(() => _restoring = true);

    MixpanelService.instance.track(
      'SpOn_Pay_Restore',
      properties: {'app_name': 'SP'},
    );

    final unlocked = await IAPService.instance.restoreAndWait();

    if (!mounted) return;
    setState(() => _restoring = false);

    if (unlocked) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const FsmePostPurchaseLanding()),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "We couldn't find a previous purchase for this account. "
            'If you were charged, please contact support.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 8),
        ),
      );
    }
  }

  // Entry point for a student who bought an in-person ServSafe class
  // through Food Safety Made Easy / Indiana Safe Food and got a free
  // unlock code from their instructor instead of buying the $4.99 IAP
  // directly. See RedeemCodeService for the offline validation scheme.
  Future<void> _showRedeemDialog() async {
    final controller = TextEditingController();
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: _darkBg,
              title: const Text(
                'Redeem a Code',
                style: TextStyle(color: _softWhite),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Got a code from your instructor? Enter it below.',
                    style: TextStyle(
                      color: _softWhite.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: _softWhite, fontSize: 18),
                    decoration: InputDecoration(
                      hintText: '12345678',
                      hintStyle: TextStyle(
                        color: _softWhite.withValues(alpha: 0.3),
                      ),
                      errorText: errorText,
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: _gold),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: _gold, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _redeeming
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: _softWhite.withValues(alpha: 0.6)),
                  ),
                ),
                TextButton(
                  onPressed: _redeeming
                      ? null
                      : () async {
                          setDialogState(() => errorText = null);
                          setState(() => _redeeming = true);
                          final result = await RedeemCodeService.redeem(
                            controller.text,
                          );
                          setState(() => _redeeming = false);
                          if (!mounted) return;
                          if (result == RedeemResult.success) {
                            Navigator.of(dialogContext).pop();
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FsmePostPurchaseLanding(),
                              ),
                              (_) => false,
                            );
                          } else {
                            setDialogState(
                              () => errorText = switch (result) {
                                RedeemResult.expired =>
                                  "That code's expired — ask your instructor for a new one.",
                                RedeemResult.alreadyRedeemed =>
                                  "That code's already been redeemed.",
                                _ => "That code didn't work.",
                              },
                            );
                          }
                        },
                  child: _redeeming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _gold,
                          ),
                        )
                      : const Text(
                          'Redeem',
                          style: TextStyle(
                            color: _gold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMeMore() {
    MixpanelService.instance.track(
      'SpOn_Pay_ShowMeMore',
      properties: {'app_name': 'SP'},
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RapidFireLimitedIntro()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contentPreference = OnboardingAnswers.instance.contentPreference;

    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'WE GOT YOU',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w500,
                  color: _gold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                "Let's get you ready\nto pass the ServSafe exam.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w500,
                  color: _softWhite,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 20),

              _recapCard(),

              const SizedBox(height: 4),

              GestureDetector(
                onTap: _startOver,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Something not right? Start over',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _softWhite.withValues(alpha: 0.4),
                      decoration: TextDecoration.underline,
                      decorationColor: _softWhite.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gold.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _darkBg,
                        border: Border.all(color: _gold),
                      ),
                      child: const Icon(
                        Icons.verified,
                        size: 15,
                        color: _gold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: _softWhite.withValues(alpha: 0.75),
                          ),
                          children: const [
                            TextSpan(text: 'Every question written by '),
                            TextSpan(
                              text: 'a certified ServSafe instructor with '
                                  '20+ years in the classroom',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _softWhite,
                              ),
                            ),
                            TextSpan(text: ' - not scraped, not generic.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Unlimited quizzes  ·  500+ questions  ·  '
                'full 90-question exam',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: _softWhite.withValues(alpha: 0.45),
                ),
              ),

              const SizedBox(height: 18),

              FsmePopup(lines: [FsmeLine(_contentLineFor(contentPreference))]),

              const SizedBox(height: 20),

              SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: _purchasing ? null : _purchase,
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
                  child: _purchasing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: _darkBg,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Unlock SafePrep \u2014 $_price',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Full access for 7 days. No limits.',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w400,
                                color: _darkBg.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 10),

              // Hidden once both free "show me more" rounds are spent \u2014
              // no dead-end tap on an offer that's already used up. See
              // AppState.hasLimitedRapidFireRoundsLeft; rounds are
              // consumed in rapid_fire_limited_intro.dart on Start.
              if (AppState().hasLimitedRapidFireRoundsLeft)
                GestureDetector(
                  onTap: _showMeMore,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Not ready to commit yet? Try this first  \u2192',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _gold,
                      ),
                    ),
                  ),
                ),

              GestureDetector(
                onTap: _restorePurchases,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _restoring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _gold,
                          ),
                        )
                      : Text(
                          'Already purchased? Restore Purchases',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _softWhite.withValues(alpha: 0.5),
                          ),
                        ),
                ),
              ),

              GestureDetector(
                onTap: _showRedeemDialog,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Have a code from your instructor? Redeem it',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _softWhite.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
