import 'app_state.dart';
import 'app_state_persistence.dart';
import 'mixpanel_service.dart';

/// Lets a student who bought an in-person ServSafe class (booked through
/// Food Safety Made Easy / Indiana Safe Food — NOT through the App
/// Store) redeem a free SafePrep Manager unlock using a short code
/// their instructor hands them after the sale. Fulfills the promo on
/// the Indiana Safe Food page: "Free SafePrep Manager unlock with
/// every purchase (1 per student)."
///
/// Deliberately offline / no backend: codes validate locally against
/// an embedded shared "secret" string rather than checking a server,
/// since SafePrep has no backend today. Trade-off, on purpose: a code
/// isn't tied to one device or marked "already used" anywhere — anyone
/// holding a valid code can redeem it more than once, on more than one
/// device. Accepted because these codes are handed out privately to
/// real known students after a real sale, never published publicly.
/// This is a goodwill perk worth $4.99, not a security boundary — the
/// checksum only needs to stop random guessing, not resist someone who
/// deliberately reverse-engineers it.
///
/// Code shape: 8 digits, "PPPPPP" + "CC" — a free 6-digit payload (the
/// instructor can type anything memorable: today's date, a student's
/// initials as a phone-keypad spelling, a running number) followed by
/// a 2-digit checksum. The checksum function is intentionally simple
/// (small-modulus running hash, no external crypto package) so it can
/// be reproduced EXACTLY in a companion generator tool the instructor
/// uses to actually produce codes — see the "SafePrep Redeem Code
/// Generator" page. If `_secret` below is ever changed, the generator
/// tool's copy of the same constant must change identically or every
/// code it produces stops validating.
class RedeemCodeService {
  RedeemCodeService._();

  static const String _secret = 'FSME-ISF-Redeem-2026';

  // Keeps every intermediate value well inside a safe integer range in
  // BOTH Dart and JavaScript (the generator tool is a plain HTML/JS
  // page), so the two implementations can never silently diverge on
  // large-number overflow/wraparound behavior. Do not "simplify" this
  // to bitwise ops or a 32-bit mask — that reintroduces exactly the
  // cross-language mismatch risk this design avoids.
  static const int _modulus = 1000003; // a prime under one million

  static String _checksumFor(String payload) {
    var hash = 0;
    for (final unit in ('$_secret$payload').codeUnits) {
      hash = (hash * 31 + unit) % _modulus;
    }
    return (hash % 100).toString().padLeft(2, '0');
  }

  static bool _isValid(String rawCode) {
    final digitsOnly = rawCode.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length != 8) return false;
    final payload = digitsOnly.substring(0, 6);
    final providedChecksum = digitsOnly.substring(6, 8);
    return providedChecksum == _checksumFor(payload);
  }

  /// Attempts to redeem [rawCode] (dashes/spaces tolerated — only the
  /// digits are checked). Returns true and unlocks the app with the
  /// same 7-day access window a real purchase grants; returns false
  /// and leaves state untouched on an invalid code.
  static Future<bool> redeem(String rawCode) async {
    final valid = _isValid(rawCode);
    MixpanelService.instance.track(
      'redeem_code_attempt',
      properties: {'app_name': 'SP', 'valid': valid},
    );
    if (!valid) return false;

    final state = AppState();
    // Same first-unlock cleanup _handleSuccess() does for a real
    // purchase, so a redeemed unlock behaves identically to a paid one
    // from here on.
    if (!state.hasUnlockedApp) {
      state.testHistory.clear();
      state.clearCurriculumProgress();
      state.hasSeenIntro = false;
    }
    state.hasUnlockedApp = true;
    state.purchaseType = PurchaseType.sevenDay;
    state.purchaseDate = DateTime.now();
    state.isRedeemedAccess = true;
    await AppStatePersistence.save();

    MixpanelService.instance.track(
      'redeem_code_success',
      properties: {'app_name': 'SP'},
    );
    return true;
  }
}
