import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/cone_calibration_settings.dart';

final calibrationRepositoryProvider = Provider<CalibrationRepository>((ref) {
  return CalibrationRepository();
});

/// Repository for persisting cone calibration settings.
class CalibrationRepository {
  static const String _settingsKey = 'cone_calibration_settings';

  /// Gets the saved calibration settings, or returns default if none saved.
  Future<ConeCalibrationSettings> getSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_settingsKey);
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        return ConeCalibrationSettings.fromJson(json);
      }
    } catch (e) {
      // If any error, return default settings
    }
    return const ConeCalibrationSettings();
  }

  /// Saves the calibration settings.
  Future<void> saveSettings(ConeCalibrationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(settings.toJson());
    await prefs.setString(_settingsKey, jsonString);
  }

  /// Resets settings to defaults.
  Future<void> resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_settingsKey);
  }
}
