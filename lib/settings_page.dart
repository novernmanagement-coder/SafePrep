import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'constants.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'home_page.dart';
import 'splash_page.dart';
import 'tips_page.dart';
import 'safe_prep_nav_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AppState _state = AppState();
  final TextEditingController _nameController = TextEditingController();
  bool _nameSaved = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = _state.userName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveName() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      _state.userName = name;
      AppStatePersistence.save();
      setState(() => _nameSaved = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _nameSaved = false);
      });
    }
  }

  Future<void> _resetProgress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset all progress?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _state.reset();
      AppStatePersistence.delete();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SplashPage()),
        );
      }
    }
  }

  Future<void> _openRefundPage() async {
    final uri = Uri.parse(
      'https://foodsafetymadeeasy.com/refund-redirect-page/',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: AppFonts.subheader,
              fontWeight: FontWeight.w600,
              color: AppColors.strongText,
            ),
          ),
          Divider(color: AppColors.cardBorder),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLegalSection(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: AppFonts.body,
            fontWeight: FontWeight.w600,
            color: AppColors.strongText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: TextStyle(
            fontSize: AppFonts.caption,
            color: AppColors.bodyText,
          ),
        ),
        Divider(color: AppColors.cardBorder.withValues(alpha: 0.4)),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppFonts.body,
                color: AppColors.subtleText,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: AppFonts.body,
              color: AppColors.strongText,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTrial = !_state.hasUnlockedApp;

    return Scaffold(
      backgroundColor: AppColors.servSafeBlue,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomePage()),
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
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  spacing: 10,
                  children: [
                    _buildSectionCard(
                      title: 'About SafePrep™',
                      children: [
                        _buildInfoRow('Version', '1.3.7'),
                        _buildInfoRow('Build', 'June 2026'),
                        _buildInfoRow('Platform', 'Flutter'),
                        const SizedBox(height: 4),
                        Text(
                          'SafePrep™ is a psychologically adaptive learning system for ServSafe® Manager exam preparation.',
                          style: TextStyle(
                            fontSize: AppFonts.caption,
                            color: AppColors.bodyText,
                          ),
                        ),
                      ],
                    ),

                    _buildSectionCard(
                      title: 'Reset Options',
                      children: [
                        Text(
                          'Your name',
                          style: TextStyle(
                            fontSize: AppFonts.caption,
                            color: AppColors.subtleText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                maxLength: 20,
                                decoration: InputDecoration(
                                  hintText: 'Enter your name…',
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 40,
                              width: 60,
                              child: ElevatedButton(
                                onPressed: _saveName,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryButton,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Save',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_nameSaved)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '✓  Name saved',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.scoreBand4,
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          'Clears all quiz scores, baselines, and curriculum progress. This cannot be undone.',
                          style: TextStyle(
                            fontSize: AppFonts.caption,
                            color: AppColors.subtleText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            onPressed: _resetProgress,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Reset Progress'),
                          ),
                        ),
                      ],
                    ),

                    _buildSectionCard(
                      title: 'Tips and Information',
                      children: [
                        Text(
                          'Exam-day tips, study strategies, and ServSafe® insights.',
                          style: TextStyle(
                            fontSize: AppFonts.caption,
                            color: AppColors.bodyText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TipsPage(),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryButton,
                              side: BorderSide(color: AppColors.primaryButton),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Open Tips and Information'),
                          ),
                        ),
                      ],
                    ),

                    _buildSectionCard(
                      title: 'Contact & Support',
                      children: [
                        Text(
                          'For questions, support, or legal inquiries:',
                          style: TextStyle(
                            fontSize: AppFonts.body,
                            color: AppColors.bodyText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.servSafeBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'info@foodsafetymadeeasy.com',
                            style: TextStyle(
                              fontSize: AppFonts.body,
                              fontWeight: FontWeight.w600,
                              color: AppColors.strongText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),

                    _buildSectionCard(
                      title: 'Legal & Compliance',
                      children: [
                        _buildLegalSection(
                          'Trademark Notice',
                          'ServSafe® is a registered trademark of the National Restaurant Association Educational Foundation. SafePrep™ is not affiliated with, endorsed by, or officially connected to the National Restaurant Association or ServSafe®. All references to ServSafe® are for descriptive purposes only.',
                        ),
                        _buildLegalSection(
                          'Disclaimer',
                          'SafePrep™ is an independent educational resource and is not affiliated with ServSafe® or the National Restaurant Association. For our guarantee policy, see below.',
                        ),
                        _buildLegalSection(
                          'Terms of Use',
                          'By using this App you agree to these Terms. The App is for educational use only. You may not modify, distribute, or reverse engineer the App or its content. The developer may update or discontinue the App at any time. The App is provided "as is" without warranties of any kind.',
                        ),
                        _buildLegalSection(
                          'Privacy & Data Handling',
                          'The App may collect limited technical or usage data for functionality and analytics. No personally identifiable information is collected unless voluntarily provided. Collected data is never sold or shared with third parties except as required by law. By using the App you consent to this policy.',
                        ),
                        _buildLegalSection(
                          'Our Guarantee',
                          'We guarantee you will pass the exam on your first try, or we will give you your money back, no questions asked.',
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: isTrial ? null : _openRefundPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryButton,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.primaryButton
                                  .withValues(alpha: 0.35),
                              disabledForegroundColor: Colors.white.withValues(
                                alpha: 0.7,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Refund'),
                          ),
                        ),
                        if (isTrial)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Refunds apply to purchases only — available once you\'ve unlocked full access.',
                              style: TextStyle(
                                fontSize: AppFonts.caption,
                                color: AppColors.subtleText,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 4),

                        Divider(
                          color: AppColors.cardBorder.withValues(alpha: 0.4),
                        ),
                        Text(
                          'Full Legal Documents',
                          style: TextStyle(
                            fontSize: AppFonts.body,
                            fontWeight: FontWeight.w600,
                            color: AppColors.strongText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Full Privacy Policy and Terms of Service are available at:',
                          style: TextStyle(
                            fontSize: AppFonts.caption,
                            color: AppColors.bodyText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.servSafeBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            spacing: 4,
                            children: [
                              Text(
                                'foodsafetymadeeasy.com/privacy-policy',
                                style: TextStyle(
                                  fontSize: AppFonts.caption,
                                  color: AppColors.strongText,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'foodsafetymadeeasy.com/terms-of-service',
                                style: TextStyle(
                                  fontSize: AppFonts.caption,
                                  color: AppColors.strongText,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
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
