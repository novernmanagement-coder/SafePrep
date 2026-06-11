import 'dart:io';
import 'package:flutter/material.dart';
import 'app_state_persistence.dart';
import 'csv_loader.dart';
import 'iap_service.dart';
import 'splash_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase — iOS and Android only
  if (Platform.isIOS || Platform.isAndroid) {
    await Firebase.initializeApp();
    FirebaseAnalytics.instance.logAppOpen();
  }

  // Load persisted user state first
  await AppStatePersistence.load();

  // Sync CSVs from GitHub in the background.
  // Won't block launch — if offline, bundled/cached files are used.
  CsvUpdater.syncIfNeeded();

  // Initialize IAP service — iOS and Android only
  if (Platform.isIOS || Platform.isAndroid) {
    await IAPService.instance.initialize();
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
