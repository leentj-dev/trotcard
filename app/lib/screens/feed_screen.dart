import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/force_update.dart';
import '../config/remote_config.dart';
import '../config/theme_controller.dart';
import '../data/song_repository.dart';
import '../models/song.dart';
import '../utils/themes.dart';
import '../widgets/native_ad_card.dart';
import 'song_screen.dart';

/// 노래 목록. 곡을 누르면 상세(유튜브 재생 + 마음 카드)로 이동한다.
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
  bool _loading = true;
  bool _showScrollTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
    // 강제 업데이트 게이트: 지금 확인하고, Remote Config 가 min_version 을
    // 올리면 앱 실행 중에도 다시 확인.
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
    final songs = await _repo.loadManifest();
    if (!mounted) return;
    setState(() {
      _songs = songs;
      _loading = false;
    });
    _syncRemote();
  }

  /// GitHub 에서 최신 곡을 받아온다. [showUpToDate] 는 당겨서 새로고침 시 true.
  Future<void> _syncRemote({bool showUpToDate = false}) async {
    final before = _songs.length;
    final updated = await _repo.syncRemote();
    if (!mounted) return;
    if (updated == null) {
      if (showUpToDate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('최신 상태예요 🎵')),
        );
      }
      return;
    }
    setState(() => _songs = updated);
    final added = updated.length - before;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added > 0 ? '새 노래 $added곡 추가됐어요 🎵' : '업데이트됐어요 🎵'),
      ),
    );
  }

  String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s'), '');

  List<SongSummary> get _filtered => _query.isEmpty
      ? _songs
      : _songs
          .where((s) =>
              _norm(s.title).contains(_norm(_query)) ||
              _norm(s.artist).contains(_norm(_query)))
          .toList();

  Future<void> _openSong(SongSummary summary) async {
    final song = await _repo.loadSong(summary.id);
    if (!mounted) return;
    final playlist = _filtered;
    final index = playlist.indexWhere((s) => s.id == summary.id);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SongScreen(
          song: song,
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
              tooltip: '맨 위로',
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
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: toggleThemeMode,
            tooltip: isDark ? '밝게' : '어둡게',
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: onSurface.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(color: onSurface, fontSize: 16),
              decoration: InputDecoration(
                hintText: '노래·가수 검색',
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: onSurface,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        s.artist,
                                        style: TextStyle(
                                            color: onSurface.withValues(
                                                alpha: 0.65),
                                            fontSize: 14),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '💌 카드 ${s.cardCount}장',
                                        style: TextStyle(
                                            color: onSurface.withValues(
                                                alpha: 0.45),
                                            fontSize: 12.5),
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
                },
              ),
            ),
    );
  }

  /// 곡 N개마다 광고 슬롯(null)을 끼워 넣는다 (Remote Config `feed_ad_interval`).
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
