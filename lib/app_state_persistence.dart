import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state.dart';

class AppStatePersistence {
  static const String _key = 'safeprep_state';
  static final AppState _state = AppState();

  static Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_state.toJson());
      await prefs.setString(_key, json);
    } catch (e) {
      print('AppState save failed: $e');
    }
  }

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json == null) {
        print('No save file found — fresh install');
        return;
      }
      _state.fromJson(jsonDecode(json));
      print('AppState loaded — user: ${_state.userName}');
    } catch (e) {
      print('AppState load failed: $e');
    }
  }

  static Future<void> delete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      print('Save file deleted');
    } catch (e) {
      print('AppState delete failed: $e');
    }
  }
}