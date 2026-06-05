import 'package:flutter/material.dart';

class RecomputingModal extends StatefulWidget {
  final String category;
  final int readinessScore;

  const RecomputingModal({
    super.key,
    required this.category,
    required this.readinessScore,
  });

  static Future<void> show(
    BuildContext context, {
    required String category,
    required int readinessScore,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) =>
          RecomputingModal(category: category, readinessScore: readinessScore),
    );
  }

  @override
  State<RecomputingModal> createState() => _RecomputingModalState();
}

class _RecomputingModalState extends State<RecomputingModal>
    with SingleTickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _mutedWhite = Color(0x99F0EDE8);

  final List<Map<String, dynamic>> _lines = [];

  @override
  void initState() {
    super.initState();
    _runSequence();
  }

  Future<void> _typeLine(String text, {int preDelayMs = 300}) async {
    await Future.delayed(Duration(milliseconds: preDelayMs));
    if (!mounted) return;

    setState(() => _lines.add({'displayedText': '', 'checked': false}));

    final charDelay = text.length > 40 ? 18 : 24;
    for (int i = 1; i <= text.length; i++) {
      await Future.delayed(Duration(milliseconds: charDelay));
      if (!mounted) return;
      setState(() => _lines.last['displayedText'] = text.substring(0, i));
    }

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _lines.last['checked'] = true);
  }

  Future<void> _runSequence() async {
    await _typeLine('Quiz results locked in.');
    await _typeLine('Recalibrating ${widget.category}...');
    await _typeLine('Curriculum refined.');
    await _typeLine('Readiness score updated — ${widget.readinessScore}%');

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _darkBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _gold.withValues(alpha: 0.2), width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _gold.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                color: _gold.withValues(alpha: 0.06),
              ),
              child: const Icon(Icons.auto_awesome, color: _gold, size: 20),
            ),

            const SizedBox(height: 14),

            Text(
              'SafePrep™ Engine',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _gold.withValues(alpha: 0.8),
                letterSpacing: 1.5,
              ),
            ),

            const SizedBox(height: 20),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _lines.map((line) {
                final displayedText = line['displayedText'] as String;
                final checked = line['checked'] as bool;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: checked
                              ? const Icon(
                                  Icons.check,
                                  key: ValueKey('checked'),
                                  size: 13,
                                  color: _gold,
                                )
                              : SizedBox(
                                  key: const ValueKey('unchecked'),
                                  width: 11,
                                  height: 11,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: _gold.withValues(alpha: 0.4),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          displayedText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                            color: _mutedWhite,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
