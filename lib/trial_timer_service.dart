import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Accumulates foreground-only usage time for unpaid users.
/// When 30 minutes is reached, calls [onTrialExpired].
class TrialTimerService with WidgetsBindingObserver {
  static const int _trialSeconds = 30 * 60; // 30 minutes
  static const String _prefKey = 'trial_elapsed_seconds';

  static final TrialTimerService instance = TrialTimerService._();
  TrialTimerService._();

  VoidCallback? onTrialExpired;

  int _elapsedSeconds = 0;
  Timer? _ticker;
  bool _running = false;
  bool _expired = false;

  /// Call once after AppStatePersistence.load() for non-unlocked users.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _elapsedSeconds = prefs.getInt(_prefKey) ?? 0;
    if (_elapsedSeconds >= _trialSeconds) {
      _expired = true;
      return;
    }
    WidgetsBinding.instance.addObserver(this);
  }

  /// Start the timer — call when HomePage first mounts.
  void start() {
    if (_expired || _running) return;
    _running = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() async {
    _elapsedSeconds++;
    // Persist every 10 seconds to avoid hammering disk
    if (_elapsedSeconds % 10 == 0) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, _elapsedSeconds);
    }
    if (_elapsedSeconds >= _trialSeconds) {
      _stop();
      _expired = true;
      onTrialExpired?.call();
    }
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
    _running = false;
  }

  /// Pause when app goes to background, resume on foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _stop();
    if (state == AppLifecycleState.resumed && !_expired) start();
  }

  /// Reset trial — call after a successful purchase.
  Future<void> resetTrial() async {
    _stop();
    _expired = false;
    _elapsedSeconds = 0;
    WidgetsBinding.instance.removeObserver(this);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  bool get isExpired => _expired;

  /// Seconds remaining in the trial, clamped to 0.
  /// Used by HomePage to display a live "Trial — mm:ss" countdown.
  int get remainingSeconds =>
      (_trialSeconds - _elapsedSeconds).clamp(0, _trialSeconds);
}
