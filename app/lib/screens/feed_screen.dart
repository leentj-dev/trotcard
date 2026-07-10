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
  String _program = ''; // 선택된 프로그램 필터('' = 전체)
  String _sort = 'recent'; // 정렬: recent/popular/title/artist
  bool _loading = true;

  static const _sortLabels = {
    'recent': '최신순',
    'popular': '인기순',
    'title': '제목순',
    'artist': '가수순',
  };
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

  /// 데이터에 존재하는 프로그램 목록(등장 순서 유지, 중복 제거).
  List<String> get _programs {
    final seen = <String>{};
    final out = <String>[];
    for (final s in _songs) {
      if (s.program.isNotEmpty && seen.add(s.program)) out.add(s.program);
    }
    return out;
  }

  List<SongSummary> get _filtered {
    var list = List<SongSummary>.of(_songs);
    if (_program.isNotEmpty) {
      list = list.where((s) => s.program == _program).toList();
    }
    if (_query.isNotEmpty) {
      list = list
          .where((s) =>
              _norm(s.title).contains(_norm(_query)) ||
              _norm(s.artist).contains(_norm(_query)))
          .toList();
    }
    switch (_sort) {
      case 'popular':
        list.sort((a, b) => b.viewCount.compareTo(a.viewCount));
        break;
      case 'title':
        list.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'artist':
        list.sort((a, b) => a.artist.compareTo(b.artist));
        break;
      case 'recent':
      default:
        list.sort((a, b) => b.order != a.order
            ? b.order.compareTo(a.order)
            : a.artist.compareTo(b.artist));
    }
    return list;
  }

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
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(appConfig.logoAsset,
                  width: 30, height: 30, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                appConfig.appTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
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
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _programChips(onSurface)),
                    _sortButton(onSurface),
                  ],
                ),
                Expanded(
                  child: ValueListenableBuilder<int>(
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
                                horizontal: 4, vertical: 10),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 176,
                                    height: 99,
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
                                            size: 42,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
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
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        s.artist,
                                        style: TextStyle(
                                            color: onSurface.withValues(
                                                alpha: 0.7),
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600),
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
                ),
              ],
            ),
    );
  }

  /// 정렬 선택 버튼(최신순/인기순/제목순/가수순).
  Widget _sortButton(Color onSurface) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 12, bottom: 4),
      child: PopupMenuButton<String>(
        initialValue: _sort,
        onSelected: (v) => setState(() => _sort = v),
        itemBuilder: (_) => _sortLabels.entries
            .map((e) => PopupMenuItem<String>(
                  value: e.key,
                  child: Text(e.value, style: const TextStyle(fontSize: 16)),
                ))
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sort_rounded, size: 18, color: onSurface),
              const SizedBox(width: 4),
              Text(_sortLabels[_sort]!,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: onSurface)),
              Icon(Icons.arrow_drop_down_rounded, size: 20, color: onSurface),
            ],
          ),
        ),
      ),
    );
  }

  /// 상단 프로그램 필터 칩 줄. 프로그램 소속 곡이 하나도 없으면 숨긴다.
  Widget _programChips(Color onSurface) {
    final programs = _programs;
    if (programs.isEmpty) return const SizedBox.shrink();
    final chips = ['', ...programs]; // '' = 전체
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final p = chips[i];
          final selected = _program == p;
          return ChoiceChip(
            label: Text(p.isEmpty ? '전체' : p),
            selected: selected,
            showCheckmark: false,
            labelStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: selected ? scheme.onPrimary : onSurface,
            ),
            selectedColor: scheme.primary,
            backgroundColor: onSurface.withValues(alpha: 0.06),
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            onSelected: (_) => setState(() => _program = p),
          );
        },
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
