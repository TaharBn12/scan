import 'package:flutter/material.dart';
import '../data/hive_database.dart';
import 'app_theme.dart';

/// Everything that changes how the app *looks*: light/dark/system, the accent
/// palette and the compact (denser) layout switch. Persisted in the settings
/// Hive box so the choice survives restarts, and exposed as a
/// [ValueNotifier] so `MaterialApp` rebuilds instantly.
class ThemeSettings {
  final ThemeMode mode;
  final String accentId;
  final bool compact;

  const ThemeSettings({
    this.mode = ThemeMode.system,
    this.accentId = 'indigo',
    this.compact = false,
  });

  AccentPalette get accent => AppTheme.accentById(accentId);

  ThemeSettings copyWith({ThemeMode? mode, String? accentId, bool? compact}) =>
      ThemeSettings(
        mode: mode ?? this.mode,
        accentId: accentId ?? this.accentId,
        compact: compact ?? this.compact,
      );
}

class ThemeController extends ValueNotifier<ThemeSettings> {
  static const _modeKey = 'theme_mode';
  static const _accentKey = 'theme_accent';
  static const _compactKey = 'compact_mode';

  ThemeController() : super(_load());

  static ThemeSettings _load() {
    final box = HiveDatabase.settingsBox;
    final saved = box.get(_modeKey) as String?;
    final mode = switch (saved) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
    return ThemeSettings(
      mode: mode,
      accentId: box.get(_accentKey) as String? ?? 'indigo',
      compact: box.get(_compactKey) as bool? ?? false,
    );
  }

  ThemeMode get mode => value.mode;
  AccentPalette get accent => value.accent;

  void setThemeMode(ThemeMode mode) {
    value = value.copyWith(mode: mode);
    HiveDatabase.settingsBox.put(_modeKey, mode.name);
  }

  void setAccent(String accentId) {
    value = value.copyWith(accentId: accentId);
    HiveDatabase.settingsBox.put(_accentKey, accentId);
  }

  void setCompact(bool compact) {
    value = value.copyWith(compact: compact);
    HiveDatabase.settingsBox.put(_compactKey, compact);
  }
}

/// Single shared instance, wired into MaterialApp in main.dart.
final themeController = ThemeController();
