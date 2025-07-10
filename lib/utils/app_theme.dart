import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  final Color primaryColor;
  final Color textColor;
  final Color secondaryColor;
  final Color secondaryTextColor;

  AppTheme({
    required this.primaryColor,
    required this.secondaryColor,
    required this.textColor,
    required this.secondaryTextColor,
  });
}

// Light and Dark Theme Definitions
final AppTheme lightTheme = AppTheme(
  primaryColor: Color.fromARGB(255, 255, 255, 255),
  secondaryColor: Color.fromARGB(255, 232, 232, 232),
  textColor: Colors.black,
  secondaryTextColor: Color.fromARGB(255, 68, 68, 68),
);

final AppTheme darkTheme = AppTheme(
    primaryColor: Color.fromARGB(255, 33, 33, 33),
    secondaryColor: Color.fromARGB(255, 68, 68, 68),
    textColor: Colors.white,
    secondaryTextColor: Color.fromARGB(255, 216, 216, 216));

// Enum for theme modes
enum AppThemeMode {
  light,
  dark,
  system,
}

class ThemeManager extends ChangeNotifier {
  AppThemeMode _appThemeMode = AppThemeMode.system;
  Brightness _platformBrightness =
      PlatformDispatcher.instance.platformBrightness;

  AppThemeMode get appThemeMode => _appThemeMode;

  ThemeMode get themeMode {
    if (_appThemeMode == AppThemeMode.light) return ThemeMode.light;
    if (_appThemeMode == AppThemeMode.dark) return ThemeMode.dark;
    return ThemeMode.system;
  }

  AppTheme get currentTheme {
    if (_appThemeMode == AppThemeMode.light) {
      return lightTheme;
    } else if (_appThemeMode == AppThemeMode.dark) {
      return darkTheme;
    } else {
      return _platformBrightness == Brightness.light ? lightTheme : darkTheme;
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _appThemeMode = mode;
    notifyListeners();
    await _saveThemeMode(mode);
  }

  Future<void> loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedTheme = prefs.getString('appThemeMode');
    if (savedTheme != null) {
      _appThemeMode =
          AppThemeMode.values.firstWhere((e) => e.toString() == savedTheme);
    } else {
      _appThemeMode = AppThemeMode.system;
    }

    PlatformDispatcher.instance.onPlatformBrightnessChanged =
        _onPlatformBrightnessChanged;
    notifyListeners();
  }

  // Update theme when platform brightness changes
  void _onPlatformBrightnessChanged() {
    final newBrightness = PlatformDispatcher.instance.platformBrightness;
    if (_appThemeMode == AppThemeMode.system &&
        newBrightness != _platformBrightness) {
      _platformBrightness = newBrightness;
      notifyListeners();
    }
  }

  Future<void> _saveThemeMode(AppThemeMode mode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('appThemeMode', mode.toString());
  }
}
