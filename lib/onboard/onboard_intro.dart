import 'package:flutter/material.dart';
import '../constants.dart';
import '../mixpanel_service.dart';
import 'onboard_exam_date.dart';

/// Screen 1 of the onboarding funnel — authority and trust.
///
/// No choices, no data capture. One job: establish that whoever built
/// this app knows the exam cold. The stat grid and credential line do
/// the heavy lifting; the headline frames everything that follows.
///
/// Next screen: "When's your exam?" (OnboardExamDate).
class OnboardIntro extends StatelessWidget {
  const OnboardIntro({super.key});

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 40, 22, 26),
          child: Column(
            children: [
              const SizedBox(height: 30),

              // Shield icon
              Icon(Icons.verified_user_outlined, size: 44, color: _gold),

              const SizedBox(height: 12),

              // Wordmark
              Text(
                'SafePrep\u2122',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _softWhite,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 16),

              // Gold divider
              Container(width: 40, height: 2, color: _gold),

              const SizedBox(height: 20),

              // Headline — every word the same color. The earlier build
              // had a stray TextSpan making "in" render differently;
              // using a single Text widget prevents that.
              Text(
                'We\u2019ll have you exam-ready\nin under 4 hours',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _softWhite,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 28),

              // 2×2 stat grid
              _statGrid(),

              const SizedBox(height: 24),

              // Credential line
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Built by Certified ServSafe\u00AE Instructors '
                  'and Registered Proctors.\n'
                  'If it\u2019s not on the test, it\u2019s not in here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: _softWhite.withValues(alpha: 0.55),
                    height: 1.6,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // NEXT button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    MixpanelService.instance.track(
                      'onboarding_intro_next',
                      properties: {'app_name': 'SP'},
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OnboardExamDate(),
                      ),
                    );
                  },
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
                    'NEXT',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
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

  Widget _statGrid() {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _statTile('20+', 'years experience'),
              const SizedBox(height: 10),
              _statTile('98%', 'Student Pass rate'),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: [
              _statTile('1,000+', 'students taught'),
              const SizedBox(height: 10),
              _statTile('500+', 'targeted questions'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statTile(String value, String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gold.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _gold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: _softWhite.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
