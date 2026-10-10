import 'package:flutter/material.dart';
import 'constants.dart';
import 'mixpanel_service.dart';
import 'fsme_eye.dart';

/// Shared "Not ready? Let us know why" sheet — used on the last Rapid
/// Fire lock screen and on the main paywall once the free rounds are
/// spent. Returns 'unlock:<reason>' if they tap Unlock, 'back' if they
/// tap the leave button, or null if they swipe it away.
Future<String?> showNotReadySheet(
  BuildContext context, {
  required String source,
  required String backLabel,
}) {
  MixpanelService.instance.track(
    'SpOn_NotReady_Opened',
    properties: {'app_name': 'SP', 'source': source},
  );
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => NotReadySheet(source: source, backLabel: backLabel),
  );
}

// ── "Not ready?" question + FSME rebuttal ──────────────────────────

class _NotReadyReason {
  final String key;
  final String label;
  final String rebuttal;
  const _NotReadyReason(this.key, this.label, this.rebuttal);
}

/// One tap-only question. Picking a reason logs it to Mixpanel, then
/// FSME types out a rebuttal followed by two exits: Unlock or Back to
/// my plan. Pops with 'unlock:<reason>' or 'back'.
class NotReadySheet extends StatefulWidget {
  /// Where the sheet was opened from ('rapid_fire' or 'paywall') —
  /// sent as `source` on every Mixpanel event.
  final String source;

  /// Label for the leave button. 'Back to my plan' from Rapid Fire,
  /// 'Close' from the paywall (they're already on their plan there).
  final String backLabel;

  const NotReadySheet({
    super.key,
    required this.source,
    required this.backLabel,
  });

  @override
  State<NotReadySheet> createState() => _NotReadySheetState();
}

class _NotReadySheetState extends State<NotReadySheet> {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _darkBg = Color(0xFF0A0A0F);
  static const Color _softWhite = Color(0xFFF0EDE8);
  static const Color _cardBg = Color(0xFF13130F);
  static const Color _eyeRed = Color(0xFFE24B4A);

  static const List<_NotReadyReason> _reasons = [
    _NotReadyReason(
      'price',
      'The price',
      'Let\u2019s do the math. \$4.99 \u2014 less than a cup from that '
          'bougie coffee shop you hit every morning. Does that coffee come '
          'with a money-back guarantee if you don\u2019t pass? Didn\u2019t '
          'think so.',
    ),
    _NotReadyReason(
      'free_content',
      'I was looking for free content',
      'Free content? Love it. Last time I took free food safety advice '
          'off the internet, it told me the five-second rule was '
          'FDA-approved.',
    ),
    _NotReadyReason(
      'other_app',
      'I\u2019m going to try a different app',
      'I get it \u2014 those other apps are cute. The last one I tried '
          'figured out I was ready by asking me, \u201cAre you ready '
          'yet?\u201d Good news: I now know the capital of Vermont is '
          'Montpelier. Sorry \u2014 we\u2019re going to have you ready in '
          'under 4 hours.',
    ),
    _NotReadyReason(
      'not_sure',
      'Not sure it\u2019ll help me pass',
      'Shhhhh\u2026 the Boss would never brag, so I\u2019ll brag for her. '
          'She still teaches classes, and in the past 10 years not one of '
          'her students has failed the exam. Plus there\u2019s a money-back '
          'guarantee. Worst case, you get your coffee back.',
    ),
    _NotReadyReason(
      'other',
      'Other',
      'Okay, I\u2019ll pop a breath mint next time I ramble on\u2026 '
          'It\u2019s my big red eyes, isn\u2019t it?',
    ),
  ];

  _NotReadyReason? _picked;
  String _typed = '';
  bool _doneTyping = false;

  /// Bumped on every pick / back-to-reasons so an older rebuttal that's
  /// still typing out stops instead of overwriting the new one.
  int _typingGen = 0;

  /// How many reasons this user has opened in this sheet (1 = first
  /// pick). Lets Mixpanel separate a first answer from browsing.
  int _pickCount = 0;

  /// Every reason they've opened, in order — sent with the exit events.
  final List<String> _seen = [];

  Future<void> _pick(_NotReadyReason r) async {
    if (_picked != null) return;
    final gen = ++_typingGen;
    _pickCount++;
    _seen.add(r.key);
    setState(() {
      _picked = r;
      _typed = '';
      _doneTyping = false;
    });

    MixpanelService.instance.track(
      'SpOn_NotReady_Reason',
      properties: {
        'app_name': 'SP',
        'source': widget.source,
        'reason': r.key,
        'pick_number': _pickCount,
        'is_first_pick': _pickCount == 1,
      },
    );

    for (var i = 1; i <= r.rebuttal.length; i++) {
      if (!mounted || gen != _typingGen) return;
      setState(() => _typed = r.rebuttal.substring(0, i));
      await Future.delayed(const Duration(milliseconds: 18));
    }
    if (mounted && gen == _typingGen) setState(() => _doneTyping = true);
  }

  /// Back to the reason list so they can read FSME's other rebuttals.
  void _backToReasons() {
    final from = _picked?.key;
    _typingGen++;
    MixpanelService.instance.track(
      'SpOn_NotReady_OtherReasons',
      properties: {
        'app_name': 'SP',
        'source': widget.source,
        'from_reason': from,
        'pick_number': _pickCount,
      },
    );
    setState(() {
      _picked = null;
      _typed = '';
      _doneTyping = false;
    });
  }

  Widget _reasonTile(_NotReadyReason r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _pick(r),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _gold.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  r.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _softWhite,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: _gold.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rebuttalView() {
    final r = _picked!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _gold.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The real animated FSME eyes (blink, gaze, pupils) — same
              // widget as the rest of the app, with the "F S M E" label
              // sitting in the gap between them like the lock-screen box.
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    FsmeEyePair(
                      mood: _doneTyping ? EyeMood.idle : EyeMood.typing,
                      size: 26,
                      spacing: 74,
                    ),
                    Text(
                      'F S M E',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 3,
                        color: _eyeRed.withValues(alpha: 0.3),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '> $_typed',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                  color: _gold.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Buttons show immediately — no waiting on FSME to finish
        // typing at the moment someone's deciding whether to buy.
        Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                          MixpanelService.instance.track(
                            'SpOn_NotReady_Unlock',
                            properties: {
                              'app_name': 'SP',
        'source': widget.source,
                              'reason': r.key,
                              'pick_number': _pickCount,
                              'reasons_seen': _seen.join(','),
                            },
                          );
                          Navigator.pop(context, 'unlock:${r.key}');
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: _darkBg,
                    disabledBackgroundColor: _gold,
                    disabledForegroundColor: _darkBg,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.buttonCornerRadius),
                    ),
                  ),
                  child: const Text(
                    'Unlock SafePrep  \u2014  \$4.99',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Full access for 7 days. No limits.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: _softWhite.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                        MixpanelService.instance.track(
                          'SpOn_NotReady_Back',
                          properties: {
                            'app_name': 'SP',
        'source': widget.source,
                            'reason': r.key,
                            'pick_number': _pickCount,
                            'reasons_seen': _seen.join(','),
                          },
                        );
                        Navigator.pop(context, 'back');
                      },
                child: Text(
                  widget.backLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: _softWhite.withValues(alpha: 0.55),
                  ),
                ),
              ),
              TextButton(
                onPressed: _backToReasons,
                child: Text(
                  '\u2190  See the other reasons',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _gold.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _unlockButton(String reasonKey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              MixpanelService.instance.track(
                'SpOn_NotReady_Unlock',
                properties: {
                  'app_name': 'SP',
                  'source': widget.source,
                  'reason': reasonKey,
                  'pick_number': _pickCount,
                  'reasons_seen': _seen.join(','),
                },
              );
              Navigator.pop(context, 'unlock:$reasonKey');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _darkBg,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppSizes.buttonCornerRadius),
              ),
            ),
            child: const Text(
              'Unlock SafePrep  \u2014  \$4.99',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Full access for 7 days. No limits.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            color: _softWhite.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
        decoration: BoxDecoration(
          color: _darkBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border(
            top: BorderSide(color: _gold.withValues(alpha: 0.3)),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _softWhite.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _picked == null
                  ? 'Let us know why you\u2019re not ready'
                  : _picked!.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _softWhite,
              ),
            ),
            const SizedBox(height: 16),
            if (_picked == null) ...[
              ..._reasons.map(_reasonTile),
              const SizedBox(height: 6),
              // Sheet covers the paywall's own button, so keep a way to
              // buy without having to pick a reason first.
              _unlockButton('none'),
            ] else
              _rebuttalView(),
          ],
          ),
        ),
      ),
    );
  }
}
