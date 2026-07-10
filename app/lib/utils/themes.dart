import 'package:flutter/material.dart';

/// Per-song color themes (ported from the web THEME_POOL).
class SongTheme {
  final Color from;
  final Color via;
  final Color accent;
  const SongTheme(this.from, this.via, this.accent);

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [from, via, Colors.black],
      );
}

const _pool = [
  SongTheme(Color(0xFF4C0519), Color(0xFF500724), Color(0xFFFDA4AF)), // rose
  SongTheme(Color(0xFF083344), Color(0xFF042F2E), Color(0xFF67E8F9)), // cyan
  SongTheme(Color(0xFF451A03), Color(0xFF422006), Color(0xFFFCD34D)), // amber
  SongTheme(Color(0xFF4A044E), Color(0xFF3B0764), Color(0xFFF0ABFC)), // fuchsia
  SongTheme(Color(0xFF1A2E05), Color(0xFF052E16), Color(0xFFBEF264)), // lime
  SongTheme(Color(0xFF082F49), Color(0xFF172554), Color(0xFF7DD3FC)), // sky
  SongTheme(Color(0xFF500724), Color(0xFF4C0519), Color(0xFFF9A8D4)), // pink
  SongTheme(Color(0xFF022C22), Color(0xFF042F2E), Color(0xFF6EE7B7)), // emerald
  SongTheme(Color(0xFF2E1065), Color(0xFF1E1B4B), Color(0xFFC4B5FD)), // violet
  SongTheme(Color(0xFF431407), Color(0xFF450A0A), Color(0xFFFDBA74)), // orange
];

SongTheme songThemeFor(String songId) =>
    _pool[songId.hashCode.abs() % _pool.length];
