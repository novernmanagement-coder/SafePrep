import 'dart:io';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'app_state_persistence.dart';
import 'csv_loader.dart';
import 'iap_service.dart';
import 'splash_page.dart';
import 'trial_timer_service.dart';
import 'mixpanel_service.dart';

// TEMP DEBUG (Aug 2026) — the splash-hang bug turned out not to be
// fully explained by the IAP fix below: something ELSE awaited before
// runApp() can also block the app on the native launch icon forever,
// with no way to see which step is stuck since nothing paints until
// runApp() finally runs (no console/cable access on this test device
// either). Every startup step is now routed through _timed(), which
// caps it at a few seconds and records ok/timeout + duration here.
// SplashPage prints this list once it finally gets to render, so
// whichever step is hanging becomes visible on-screen instead of
// silently freezing the whole app. Remove startupDiagnostics, _timed,
// and the debug block in splash_page.dart once Android startup is
// confirmed reliably fast.
final List<String> startupDiagnostics = [];

Future<void> _timed(
  String label,
  Future<void> Function() action, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  final sw = Stopwatch()..start();
  try {
    await action().timeout(timeout);
    startupDiagnostics.add('$label: ok (${sw.elapsedMilliseconds}ms)');
  } catch (e) {
    startupDiagnostics.add(
      '$label: TIMEOUT/FAILED after ${sw.elapsedMilliseconds}ms — $e',
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Mixpanel
  await _timed('Mixpanel init', () => MixpanelService.instance.init());

  // Load persisted user state first
  await _timed('AppState load', () => AppStatePersistence.load());

  // Init trial timer for non-unlocked users
  if (!AppState().hasUnlockedApp) {
    await _timed('TrialTimer init', () => TrialTimerService.instance.init());
  }

  // Sync CSVs from GitHub in the background.
  // Won't block launch — if offline, bundled/cached files are used.
  CsvUpdater.syncIfNeeded();

  // Initialize IAP service — iOS and Android only.
  //
  // FIXED (Aug 2026): this used to be awaited here, which meant the
  // whole app — including SplashPage — could not paint its first
  // Flutter frame until Play Billing/StoreKit finished connecting.
  // The native Android launch icon shows automatically while waiting
  // for that first frame, so a slow or hung billing connection (seen
  // right after a fresh Play Store install) left the app stuck on
  // that icon forever: no error, no Flutter UI, nothing. Fire this
  // off in the background instead, same as CsvUpdater.syncIfNeeded()
  // just above — the paywall already handles products not being
  // loaded yet (IAPResult.productNotFound / lastLoadDiagnostic) and
  // retries _loadProducts() itself if a product is missing when a
  // purchase is attempted.
  if (Platform.isIOS || Platform.isAndroid) {
    IAPService.instance.initialize();
  }

  runApp(const SafePrepApp());
}

class SafePrepApp extends StatelessWidget {
  const SafePrepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafePrep',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0077C8)),
        useMaterial3: true,
      ),
      home: const SplashPage(),
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390, maxHeight: 844),
            child: child!,
          ),
        );
      },
    );
  }
}
