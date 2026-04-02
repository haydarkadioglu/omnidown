import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._prefs) {
    // Load saved theme mode or default to system
    final isDark = _prefs.getBool('isDark');
    if (isDark == null) {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    }
  }

  final SharedPreferences _prefs;
  late ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void toggleTheme() {
    if (isDarkMode) {
      _themeMode = ThemeMode.light;
      _prefs.setBool('isDark', false);
    } else {
      _themeMode = ThemeMode.dark;
      _prefs.setBool('isDark', true);
    }
    notifyListeners();
  }
}
