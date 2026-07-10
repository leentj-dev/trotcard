import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../config/build_flags.dart';
import '../config/force_update.dart';
import '../config/remote_config.dart';
import '../config/theme_controller.dart';
import '../data/song_repository.dart';
import '../models/song.dart';
import '../utils/languages.dart';
import '../utils/themes.dart';
import '../widgets/native_ad_card.dart';
import 'song_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _repo = SongRepository();
  final _scrollController = ScrollController();
  List<SongSummary> _songs = [];
  String _query = '';
  String _lang = 'english';
  bool _loading = true;
  bool _showScrollTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
    // Force-update gate: check now, and again if Remote Config pushes a higher
    // min_version while the app is open.
    minVersionNotifier.addListener(_checkForceUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForceUpdate());
  }

  void _checkForceUpdate() {
    if (mounted) maybeForceUpdate(context, minVersionNotifier.value);
  }

  @override
  void dispose() {
    minVersionNotifier.removeListener(_checkForceUpdate);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scrollController.offset > 600;
    if (show != _showScrollTop) setState(() => _showScrollTop = show);
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final songs = await _repo.loadManifest();
    if (!mounted) return;
    setState(() {
      _lang = prefs.getString('lang') ?? 'english';
      _songs = songs;
      _loading = false;
    });
    _syncRemote();
  }

  /// Pulls the latest songs from GitHub. [showUpToDate] is true when triggered
  /// by pull-to-refresh, so we confirm even when nothing changed.
  Future<void> _syncRemote({bool showUpToDate = false}) async {
    final before = _songs.length;
    final updated = await _repo.syncRemote();
    if (!mounted) return;
    if (updated == null) {
      if (showUpToDate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Up to date 🎵')),
        );
      }
      return;
    }
    setState(() => _songs = updated);
    final added = updated.length - before;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added > 0 ? 'New songs added: $added 🎵' : 'Updated 🎵'),
      ),
    );
  }

  Future<void> _setLang(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', lang);
    setState(() => _lang = lang);
  }

  String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s'), '');

  List<SongSummary> get _filtered => _query.isEmpty
      ? _songs
      : _songs
          .where((s) =>
              _norm(s.title).contains(_norm(_query)) ||
              _norm(s.artist).contains(_norm(_query)))
          .toList();

  /// Gathers every song the user adjusted (SharedPreferences `offset_<id>`)
  /// into a compact text block to copy and hand to the dev, who applies the
  /// values to the song JSON (introOffset) and pushes.
  Future<void> _exportOffsets() async {
    final prefs = await SharedPreferences.getInstance();
    final lines = <String>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('offset_')) continue;
      final value = prefs.getDouble(key);
      if (value != null) {
        lines.add('${key.substring('offset_'.length)}: '
            '${value.toStringAsFixed(1)}');
      }
    }
    lines.sort();
    final payload = lines.join('\n');
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Sync offsets',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SingleChildScrollView(
          child: SelectableText(
            payload.isEmpty ? '(no adjustments saved yet)' : payload,
            style: const TextStyle(
                color: Colors.white70, fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child:
                const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
          if (payload.isNotEmpty)
            FilledButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: payload));
                if (dctx.mounted) Navigator.of(dctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Copied — send it to the dev')),
                  );
                }
              },
              child: const Text('Copy'),
            ),
        ],
      ),
    );
  }

  Future<void> _openSong(SongSummary summary) async {
    final song = await _repo.loadSong(summary.id);
    if (!mounted) return;
    // Playlist = songs only (ads excluded), starting at the tapped song.
    final playlist = _filtered;
    final index = playlist.indexWhere((s) => s.id == summary.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SongScreen(
          song: song,
          lang: _lang,
          playlist: playlist,
          index: index < 0 ? 0 : index,
          repo: _repo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      floatingActionButton: _showScrollTop
          ? FloatingActionButton.small(
              onPressed: _scrollToTop,
              backgroundColor: onSurface.withValues(alpha: 0.14),
              foregroundColor: onSurface,
              tooltip: 'Scroll to top',
              child: const Icon(Icons.keyboard_arrow_up_rounded),
            )
          : null,
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(appConfig.logoAsset,
                  width: 30, height: 30, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            Text(
              appConfig.appTitle,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        actions: [
          if (kDevTools)
            IconButton(
              onPressed: _exportOffsets,
              tooltip: 'Export sync offsets',
              icon: Icon(Icons.ios_share_rounded,
                  color: onSurface.withValues(alpha: 0.85)),
            ),
          IconButton(
            onPressed: toggleThemeMode,
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: onSurface.withValues(alpha: 0.85),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PopupMenuButton<String>(
              initialValue: _lang,
              onSelected: _setLang,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              offset: const Offset(0, 44),
              itemBuilder: (context) => [
                for (final key in appConfig.target.uiLanguages)
                  PopupMenuItem(
                    value: key,
                    child: Row(
                      children: [
                        Icon(
                          key == _lang
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 18,
                          color: key == _lang
                              ? const Color(0xFFF0ABFC)
                              : onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(width: 10),
                        Text(supportedLanguages[key] ?? key,
                            style: TextStyle(color: onSurface)),
                      ],
                    ),
                  ),
              ],
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: onSurface.withValues(alpha: 0.18)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language_rounded,
                        size: 16, color: onSurface.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Text(
                      supportedLanguages[_lang] ?? 'English',
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: onSurface.withValues(alpha: 0.5)),
                  ],
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(color: onSurface),
              decoration: InputDecoration(
                hintText: 'Search songs or artists',
                hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.38)),
                prefixIcon:
                    Icon(Icons.search, color: onSurface.withValues(alpha: 0.38)),
                filled: true,
                fillColor: onSurface.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<int>(
              valueListenable: feedAdIntervalNotifier,
              builder: (context, _, _) => ValueListenableBuilder<bool>(
              valueListenable: adsEnabledNotifier,
              builder: (context, adsOn, _) {
              final List<SongSummary?> items =
                  adsOn ? _withAds(_filtered) : _filtered;
              return RefreshIndicator(
                onRefresh: () => _syncRemote(showUpToDate: true),
                child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final s = items[i];
                  if (s == null) return const NativeAdCard();
                  final theme = songThemeFor(s.id);
                  return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _openSong(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 6),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 136,
                            height: 76,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                      gradient: theme.gradient),
                                ),
                                Image.network(
                                  'https://img.youtube.com/vi/${s.youtubeId}/mqdefault.jpg',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Center(
                                    child: Icon(Icons.music_note_rounded,
                                        color: theme.accent, size: 32),
                                  ),
                                ),
                                const Center(
                                  child: Icon(
                                    Icons.play_circle_fill_rounded,
                                    color: Colors.white70,
                                    size: 30,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                s.artist,
                                style: TextStyle(
                                    color: theme.accent, fontSize: 12.5),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${s.wordCount} words',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                },
              ),
              );
            })),
    );
  }

  /// Interleaves null ad-slots after every N songs (from Remote Config,
  /// `feed_ad_interval`), no trailing ad.
  List<SongSummary?> _withAds(List<SongSummary> songs) {
    final interval = feedAdIntervalNotifier.value;
    final out = <SongSummary?>[];
    for (var i = 0; i < songs.length; i++) {
      out.add(songs[i]);
      final isLast = i == songs.length - 1;
      if (!isLast && (i + 1) % interval == 0) out.add(null);
    }
    return out;
  }
}
