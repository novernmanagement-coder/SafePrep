import 'package:flutter/material.dart';
import 'home_page.dart';
import 'constants.dart';
import 'app_state.dart';

class IntroductoryPage extends StatefulWidget {
  const IntroductoryPage({super.key});

  @override
  State<IntroductoryPage> createState() => _IntroductoryPageState();
}

class _IntroductoryPageState extends State<IntroductoryPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  bool _showTapHint = false;
  late AnimationController _bobbingController;
  late Animation<double> _bobbingAnimation;

  @override
  void initState() {
    super.initState();
    _bobbingController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _bobbingAnimation = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _bobbingController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bobbingController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _saveName() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      AppState().userName = name;
    }
  }

  void _showHint() {
    setState(() => _showTapHint = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showTapHint = false);
    });
  }

  void _onIconTapped() {
    _saveName();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = AppState().hasTakenAssessment;

    final resultsMessage = hasResults
        ? 'We already have your assessment results on file \u2014 your personalized curriculum is built and ready to go.\n\nIf you\u2019d prefer to start fresh, you can retake the assessment anytime from the home page.'
        : 'Head to the home page to take your free diagnostic assessment \u2014 we\u2019ll build your personalized curriculum from there.';

    return Scaffold(
      backgroundColor: AppColors.primaryButton,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: AppSizes.pageMargin,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: AppSizes.bodySpacing,
                children: [
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _onIconTapped,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Image.asset(
                            'Assets/splash.png',
                            width: AppSizes.iconLarge,
                            height: AppSizes.iconLarge,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedBuilder(
                        animation: _bobbingAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _bobbingAnimation.value),
                            child: const Text(
                              '▲',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tap the icon to go to the Home Page',
                        style: TextStyle(
                          fontSize: AppFonts.caption,
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                  // Congratulations headline
                  const Text(
                    'Congratulations.',
                    style: TextStyle(
                      fontSize: AppFonts.title,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Core message
                  const Text(
                    'You just made the smartest move toward passing your ServSafe\u00ae exam.\n\nSafePrep\u2122 was built for one purpose \u2014 to get you ready. Not with generic questions and guesswork, but with a system that learns you, adapts to you, and builds a curriculum around your results.\n\nYou\u2019re not just studying. You\u2019re preparing.',
                    style: TextStyle(
                      fontSize: AppFonts.body,
                      color: Colors.white70,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Context-aware results message
                  Text(
                    resultsMessage,
                    style: const TextStyle(
                      fontSize: AppFonts.body,
                      color: Colors.white70,
                      height: 1.6,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  Column(
                    spacing: AppSizes.headerSpacing,
                    children: [
                      const Text(
                        'What name do you like to go by?',
                        style: TextStyle(
                          fontSize: AppFonts.body,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(
                        width: AppSizes.primaryButtonWidth,
                        child: TextField(
                          controller: _nameController,
                          textAlign: TextAlign.center,
                          maxLength: 20,
                          decoration: const InputDecoration(
                            hintText: 'Enter your name',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                            counterText: '',
                          ),
                          onSubmitted: (_) {
                            _saveName();
                            _showHint();
                          },
                          onEditingComplete: () {
                            if (_nameController.text.trim().isNotEmpty) {
                              _saveName();
                              _showHint();
                            }
                          },
                        ),
                      ),
                      const Text(
                        '(Optional)',
                        style: TextStyle(
                          fontSize: AppFonts.caption,
                          color: Colors.white54,
                        ),
                      ),
                      if (_showTapHint)
                        const Text(
                          'Tap the icon above to continue',
                          style: TextStyle(
                            fontSize: AppFonts.question,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),

                  Column(
                    spacing: AppSizes.footerSpacing,
                    children: [
                      Text(
                        AppStrings.footerLine1,
                        style: const TextStyle(
                          fontSize: AppFonts.footer,
                          color: Colors.white54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        AppStrings.footerLine2,
                        style: const TextStyle(
                          fontSize: AppFonts.footer,
                          color: Colors.white54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        AppStrings.footerLine3,
                        style: const TextStyle(
                          fontSize: AppFonts.footer,
                          color: AppColors.starMotifBlue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
