// lib/mock/mock_dashboard_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// MOCK SCREEN — App Store Screenshot use only. Remove before production build.
// Shot 2: Dashboard — "system at work"
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

class MockDashboardScreen extends StatelessWidget {
  const MockDashboardScreen({super.key});

  // ── Hardcoded ideal data ──────────────────────────────────────────────────
  static const String _userName = 'Alex';

  static const int _latestScore = 81;
  static const int _baselineScore = 52;
  static const int _delta = 29;
  static const int _curriculumPct = 63;
  static const int _masteredCount = 5;
  static const int _totalCount = 8;
  static const int _studiedCount = 7;

  static const List<Map<String, dynamic>> _studyCategories = [
    {'name': 'Cross-Contamination', 'score': 71, 'baseline': 44, 'pulse': true},
    {
      'name': 'Food Safety Management',
      'score': 78,
      'baseline': 50,
      'pulse': false,
    },
  ];

  // ── Colors ────────────────────────────────────────────────────────────────
  static const Color _bgBlue = Color(0xFF0A1628);
  static const Color _cardBg = Color(0xFF1A1A1A);
  static const Color _accentBlue = Color(0xFF4DA3FF);
  static const Color _bodyText = Color(0xFFE0E0E0);
  static const Color _subText = Color(0xFF8A8A8A);
  static const Color _divider = Color(0xFF2C2C2C);
  static const Color _greenScore = Color(0xFF4CAF50);
  static const Color _yellowScore = Color(0xFFFFB300);
  static const Color _goldFrame = Color(0xFFD4AF37);
  static const Color _primaryButton = Color(0xFF1565C0);
  static const Color _footerText = Color(0xFF6A6A6A);

  Color _scoreColor(int pct) {
    if (pct <= 50) return const Color(0xFFE53935);
    if (pct <= 65) return const Color(0xFFFF7043);
    if (pct <= 84) return _yellowScore;
    return _greenScore;
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _wowBanner() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFF2E4374),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF0C575), width: 1.5),
          ),
          child: const Text(
            'We show you exactly what to study next.',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.15,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF2E4374),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF0C575), width: 1.5),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Built by a ServSafe\u00AE instructor',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.15,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 3),
              Text(
                '20 years preparing people for the real exam.',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFC7D3EC),
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Safe',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _bodyText,
            ),
          ),
          const SizedBox(width: 6),
          Image.asset('Assets/splash.png', width: 36, height: 36),
          const SizedBox(width: 6),
          Text(
            'Prep™',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _bodyText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCards() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _summaryCard(
              label: 'OVERALL SCORE PROGRESS',
              value: '$_latestScore%',
              valueColor: _scoreColor(_latestScore),
              sub1: '+$_delta vs baseline',
              sub2: 'Baseline: $_baselineScore%',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _summaryCard(
              label: 'CURRICULUM PROGRESS',
              value: '$_curriculumPct%',
              valueColor: _accentBlue,
              sub1: '$_masteredCount of $_totalCount categories',
              sub2: '$_studiedCount studied',
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required Color valueColor,
    required String sub1,
    required String sub2,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _accentBlue, width: 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _accentBlue,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(sub1, style: const TextStyle(color: _accentBlue, fontSize: 10)),
          const SizedBox(height: 2),
          Text(sub2, style: const TextStyle(color: _subText, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _studyCategoryCard(Map<String, dynamic> cat) {
    final bool pulse = cat['pulse'] as bool;
    final int score = cat['score'] as int;
    final int baseline = cat['baseline'] as int;
    final String name = cat['name'] as String;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _accentBlue, width: 4),
        boxShadow: pulse
            ? [
                BoxShadow(
                  color: _accentBlue.withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name.toUpperCase(),
            style: const TextStyle(
              color: _accentBlue,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$score%',
            style: TextStyle(
              color: _scoreColor(score),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Baseline: $baseline%',
            style: const TextStyle(color: _subText, fontSize: 10),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 28,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentBlue,
                disabledBackgroundColor: _accentBlue,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'Study →',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studyGrid() {
    final rows = <Widget>[];
    for (int i = 0; i < _studyCategories.length; i += 2) {
      final cat1 = _studyCategories[i];
      final cat2 = i + 1 < _studyCategories.length
          ? _studyCategories[i + 1]
          : null;
      rows.add(
        Row(
          children: [
            Expanded(child: _studyCategoryCard(cat1)),
            const SizedBox(width: 12),
            Expanded(
              child: cat2 != null ? _studyCategoryCard(cat2) : const SizedBox(),
            ),
          ],
        ),
      );
      if (i + 2 < _studyCategories.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }

  @override
  Widget build(BuildContext context) {
    final screenContent = Scaffold(
      backgroundColor: _bgBlue,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              _header(),

              // Dashboard title — above banners
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  'SafePrep™ $_userName\'s Dashboard',
                  style: const TextStyle(
                    color: _bodyText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),

              _wowBanner(),

              // ── Main dashboard card ──────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    _summaryCards(),
                    const SizedBox(height: 8),
                    const Divider(color: _divider),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Study Categories',
                            style: TextStyle(
                              color: _bodyText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '▼',
                          style: TextStyle(color: _accentBlue, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _studyGrid(),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 280,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryButton,
                          disabledBackgroundColor: _primaryButton,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '⏱ 60-Second Refresh',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Footer
              const Column(
                children: [
                  Text(
                    'ServSafe® is a registered trademark of the',
                    style: TextStyle(fontSize: 9, color: _footerText),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'National Restaurant Association Educational Foundation.',
                    style: TextStyle(fontSize: 9, color: _footerText),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'SafePrep is an independent prep tool.',
                    style: TextStyle(fontSize: 9, color: _accentBlue),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );

    // ── Gold frame (matching Shot 1) ─────────────────────────────────────────
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: _goldFrame, width: 6),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _goldFrame.withValues(alpha: 0.35),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: screenContent,
          ),
        ),
      ),
    );
  }
}
