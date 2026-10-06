// lib/features/core/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode state
enum AppThemeMode { light, dark, system }

/// Theme state notifier
class ThemeNotifier extends StateNotifier<ThemeMode> {
  static const String _storageKey = 'app_theme_mode';

  ThemeNotifier() : super(ThemeMode.light) {
    // ✅ Default to light mode
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString(_storageKey);
      if (mode != null) {
        state = ThemeMode.values.firstWhere(
          (e) => e.name == mode,
          orElse: () => ThemeMode.system,
        );
      }
    } catch (e) {
      // Use system default on error
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, mode.name);
    } catch (e) {
      // Ignore storage errors
    }
  }

  void toggleTheme() {
    switch (state) {
      case ThemeMode.light:
        setTheme(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        setTheme(ThemeMode.light);
        break;
      case ThemeMode.system:
        setTheme(ThemeMode.dark);
        break;
    }
  }

  bool get isDarkMode => state == ThemeMode.dark;
  bool get isLightMode => state == ThemeMode.light;
  bool get isSystemMode => state == ThemeMode.system;
}

/// Theme provider
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>(
  (ref) => ThemeNotifier(),
);
