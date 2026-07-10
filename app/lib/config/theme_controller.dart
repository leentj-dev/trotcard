import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide dark/light mode, persisted locally. Defaults to dark since the
/// player/word-card screens are designed for it; the feed chrome adapts.
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

Future<void> loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('darkMode') ?? true;
  themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
}

Future<void> toggleThemeMode() async {
  final next = themeModeNotifier.value == ThemeMode.dark
      ? ThemeMode.light
      : ThemeMode.dark;
  themeModeNotifier.value = next;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('darkMode', next == ThemeMode.dark);
}
