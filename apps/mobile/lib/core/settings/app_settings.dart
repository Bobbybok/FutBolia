import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const _kNotifs = 'settings.notificationsEnabled';
  static const _kWordFilter = 'settings.wordFilterEnabled';

  bool _notificationsEnabled = true;
  bool _wordFilterEnabled = true;
  bool _loaded = false;

  bool get loaded => _loaded;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get wordFilterEnabled => _wordFilterEnabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool(_kNotifs) ?? true;
    _wordFilterEnabled = prefs.getBool(_kWordFilter) ?? true;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    if (_notificationsEnabled == value) return;
    _notificationsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifs, value);
  }

  Future<void> setWordFilterEnabled(bool value) async {
    if (_wordFilterEnabled == value) return;
    _wordFilterEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWordFilter, value);
  }
}
