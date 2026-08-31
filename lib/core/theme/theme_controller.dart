import 'package:flutter/material.dart';
import '../data/hive_database.dart';

/// Holds the current [ThemeMode] and persists the choice in the settings
/// Hive box so it survives app restarts. Wrapped in a ValueListenableBuilder
/// in main.dart so changing it rebuilds MaterialApp.router with the new mode.
class ThemeController extends ValueNotifier<ThemeMode> {
  static const _key = 'theme_mode';

  ThemeController() : super(_loadInitial());

  static ThemeMode _loadInitial() {
    final saved = HiveDatabase.settingsBox.get(_key) as String?;
    switch (saved) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  void setThemeMode(ThemeMode mode) {
    value = mode;
    HiveDatabase.settingsBox.put(_key, mode.name);
  }
}

/// Single shared instance used across the app (main.dart wires it into
/// MaterialApp.router; any settings screen can call
/// `themeController.setThemeMode(...)` to change it).
final themeController = ThemeController();
