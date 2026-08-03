import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../mixpanel_service.dart';
import '../iap_service.dart';
import '../fsme_popup.dart';
import 'onboard_answers.dart';
import 'onboard_knowledge_level.dart';
import 'onboard_post_purchase.dart';
import '../rapid_fire_limited_intro.dart';

/// Onboarding paywall — redesigned for the self-report funnel.
///
/// One product now ($4.99, 7 days full access) since the Refresher
/// tier has been eliminated entirely — there's nothing to price-game
/// toward, so the screen is a single clean ask rather than two priced
/// options. The subline and FSME's one-line reaction both key off the
/// knowledge level the user self-reported earlier in the funnel
/// (Confident / Prepared / Almost ready / New to ServSafe) — copy
/// only, never a different product or different curriculum.
///
/// "Show me more first" routes to the Rapid Fire preview as a taste
/// of the tool before a second ask, rather than a hard decline exit.
///
/// FSME's role here is deliberately minimal — one reactive line via
/// the shared [FsmePopup] widget, no authored multi-beat script.
class OnboardPaywall extends StatefulWidget {
  const OnboardPaywall({super.key});

  @override
  State<OnboardPaywall> createState() => _OnboardPaywallState();
}

class _OnboardPaywallState extends State<OnboardPaywall> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);

  static const String _price = '\$4.99';

  bool _purchasing = false;

  /// FSME's one-line reaction, keyed to the self-reported knowledge
  /// level. Draft copy — only the "confident" line has been confirmed
  /// against the mockup; the other three are proposed and open to
  /// editing.
  String _fsmeLineFor(KnowledgeLevel? level) {
    switch (level) {
      case KnowledgeLevel.confident:
        return "You said confident \u2014 good. This\u2019ll keep you "
            'sharp, not slow you down. That\u2019s the whole design.';
      case KnowledgeLevel.prepared:
        return "Prepared\u2019s a good spot to be. This tightens up "
            'whatever\u2019s left before you walk in.';
      case KnowledgeLevel.almostReady:
        return 'Almost there \u2014 this closes the gaps fast, not '
            'from scratch.';
      case KnowledgeLevel.newToServSafe:
        return 'Starting fresh? This is built to get you all the way '
            'there, step by step.';
      case null:
        return "This is built to get you exam-ready, whatever you're "
            'starting from.';
    }
  }

  @override
  void initState() {
    super.initState();
    MixpanelService.instance.track(
      'SpOn_Pay_Viewed',
      properties: {
        'app_name': 'SP',
        'knowledge_level':
            OnboardingAnswers.instance.knowledgeLevel?.tag ?? 'unknown',
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
        'knowledge_level':
            OnboardingAnswers.instance.knowledgeLevel?.tag ?? 'unknown',
      },
    );

    final result = await IAPService.instance.buySevenDay();

    if (!mounted) return;
    setState(() => _purchasing = false);

    if (result == IAPResult.success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardPostPurchase()),
        (_) => false,
      );
    } else if (result != IAPResult.canceled) {
      final message = result.userMessage;
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
    }
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
    final level = OnboardingAnswers.instance.knowledgeLevel;

    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'YOUR PLAN IS READY',
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
                'One plan.\nEverything included.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w500,
                  color: _softWhite,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Built from your readiness level.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: _gold.withValues(alpha: 0.7),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Unlimited quizzes, 500+ questions,\n'
                'a full 90-question exam.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: _softWhite.withValues(alpha: 0.45),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 22),

              FsmePopup(
                lines: [FsmeLine(_fsmeLineFor(level))],
              ),

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
            ],
          ),
        ),
      ),
    );
  }
}