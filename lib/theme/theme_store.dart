import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

/// Holds the currently selected app theme and persists the choice
/// locally so it survives restarts. Screens rebuild on change via
/// ListenableBuilder(listenable: themeStore), same pattern as
/// DeviceStore for device data.
class ThemeStore extends ChangeNotifier {
  static const _prefsKey = 'app_theme_id';

  AppColors _colors = appThemes.first;

  AppColors get colors => _colors;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefsKey);
    if (id != null) {
      _colors = themeById(id);
      notifyListeners();
    }
  }

  Future<void> select(String id) async {
    _colors = themeById(id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, id);
  }
}
