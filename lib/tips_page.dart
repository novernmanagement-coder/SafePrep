import 'package:flutter/material.dart';
import 'constants.dart';
import 'home_page.dart';
import 'safe_prep_nav_bar.dart';

class TipsPage extends StatelessWidget {
  const TipsPage({super.key});

  Widget _buildCard(String title, List<String> paragraphs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: AppFonts.subheader,
              color: AppColors.strongText,
            ),
          ),
          ...paragraphs.map(
            (p) => Text(
              p,
              style: TextStyle(
                fontSize: AppFonts.body,
                color: AppColors.bodyText,
              ),
            ),
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
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    _buildCard('What Is a Proctor', [
                      'A proctor is a certified person who supervises your ServSafe® exam to make sure everything is done fairly and securely. They verify your identity, monitor the testing environment, and ensure exam rules are followed.',
                    ]),
                    _buildCard('How to Find a Proctor', [
                      'You can find a certified proctor by visiting ServSafe.com, selecting Exams, choosing Find a Proctor, and entering your ZIP code. You can then contact a proctor or test center directly to schedule your exam.',
                      'A certified proctor must be physically present with you during the entire exam. This ensures identity verification, a proper testing environment, and secure submission of your exam.',
                      'Some areas also offer approved test centers, which provide a testing room, a certified proctor on site, and computer stations.',
                    ]),
                    _buildCard('Cost of Proctoring', [
                      'Proctoring fees vary by location and provider. Typical costs range from 35 to 75 dollars. Some proctors include room use, computer access, or administrative fees in their pricing.',
                    ]),
                    _buildCard('Cost of the Exam', [
                      'Exam pricing varies depending on whether you purchase the exam only or a course and exam bundle. Typical exam only pricing ranges from 36 to 50 dollars.',
                    ]),
                    _buildCard('How to Purchase the Exam', [
                      'Students can purchase their own exam directly on the ServSafe® website. Go to ServSafe.com, select Exams, choose ServSafe® Manager Exam, and complete checkout. Students will receive an exam voucher code to bring on test day.',
                      'Some proctors offer a combined package that includes the exam, proctoring services, and use of a testing room or computer. In these cases, the student does not need to purchase the exam separately.',
                    ]),
                    _buildCard('How Long the Exam Takes', [
                      'The ServSafe® Manager exam allows up to 2 hours. Most people finish in 60 to 90 minutes. Your proctor will let you know when the exam begins and how much time remains.',
                    ]),
                    _buildCard('When You Get Your Results', [
                      'Online exams typically score immediately after submission. Paper exams may take 3 to 10 business days depending on processing time.',
                    ]),
                    _buildCard('What to Bring', [
                      'Most proctors require a valid government issued photo ID and any exam voucher you were provided. Phones, notes, books, and smart devices are not allowed during the exam.',
                    ]),
                    _buildCard('Tips for Exam Day', [
                      'Arrive early, bring your ID, use the restroom before starting, and ask any questions before the exam begins. Stay calm and take your time. You can flag questions and return to them.',
                    ]),
                    const SizedBox(height: 12),
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
