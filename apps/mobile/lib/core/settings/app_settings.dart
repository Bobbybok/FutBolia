import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const _kDark = 'settings.darkMode';
  static const _kNotifs = 'settings.notificationsEnabled';

  bool _darkMode = false;
  bool _notificationsEnabled = true;
  bool _loaded = false;

  bool get loaded => _loaded;
  bool get darkMode => _darkMode;
  bool get notificationsEnabled => _notificationsEnabled;
  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _darkMode = prefs.getBool(_kDark) ?? false;
    _notificationsEnabled = prefs.getBool(_kNotifs) ?? true;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    if (_darkMode == value) return;
    _darkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDark, value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    if (_notificationsEnabled == value) return;
    _notificationsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifs, value);
  }
}
