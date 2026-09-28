import 'package:flutter/material.dart';
import '../core/security/secure_vault.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final saved = await SecureVault().getThemeMode();
      if (saved != null) {
        if (saved == 'light') {
          _themeMode = ThemeMode.light;
        } else if (saved == 'dark') {
          _themeMode = ThemeMode.dark;
        } else if (saved == 'system') {
          _themeMode = ThemeMode.system;
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    SecureVault().saveThemeMode(_themeMode.name).catchError((_) {});
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
      SecureVault().saveThemeMode(_themeMode.name).catchError((_) {});
    }
  }
}
