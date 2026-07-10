import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../config/remote_config.dart';
import '../data/song_repository.dart';
import '../models/song.dart';
import '../utils/themes.dart';
import '../widgets/greeting_card.dart';
import '../widgets/pager_ads.dart';

/// 노래 상세 — 위에 유튜브로 트롯을 재생하며, 아래 마음 카드가 4초마다 자동으로
/// 넘어간다. 사용자가 스와이프하면 그대로 두고, 멈추면 10초 뒤 다시 자동 재개.
/// 끝까지 가면 처음으로 돌아온다. 카드 사이엔 네이티브 광고를 끼운다(간격은
/// Remote Config `card_ad_interval`, 기본 5).
class SongScreen extends StatefulWidget {
  final Song song;
  final List<SongSummary> playlist;
  final int index;
  final SongRepository repo;

  const SongScreen({
    super.key,
    required this.song,
    required this.playlist,
    required this.index,
    required this.repo,
  });

  @override
  State<SongScreen> createState() => _SongScreenState();
}

class _SongScreenState extends State<SongScreen> {
  late final YoutubePlayerController _player;
  late final PageController _pageController;
  late Song _song;
  late int _index;
  bool _advancing = false;

  /// 현재 페이지(광고 포함 items 기준) + 현재 아이템 개수(타이머용).
  int _currentPage = 0;
  int _itemCount = 0;

  Timer? _autoTimer; // 4초 자동 넘김
  Timer? _resumeTimer; // 사용자 조작 후 10초 뒤 재개
  bool _userInteracting = false;

  static const _autoInterval = Duration(seconds: 4);
  static const _resumeDelay = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _song = widget.song;
    _index = widget.index;
    _pageController = PageController(viewportFraction: 0.82);
    _player = YoutubePlayerController.fromVideoId(
      videoId: _song.youtubeId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: false,
        strictRelatedVideos: true,
      ),
    );
    _player.listen((value) {
      if (value.playerState == PlayerState.ended) _playNext();
    });
    _startAuto();
  }

  // ── 자동 넘김 ──────────────────────────────────────────────
  void _startAuto() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(_autoInterval, (_) => _autoAdvance());
  }

  void _autoAdvance() {
    if (!mounted || _userInteracting || _itemCount == 0) return;
    if (!_pageController.hasClients) return;
    final next = _currentPage + 1 >= _itemCount ? 0 : _currentPage + 1;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  /// 사용자가 손으로 스와이프 시작 → 자동 넘김 잠시 양보.
  void _onUserDragStart() {
    _userInteracting = true;
    _resumeTimer?.cancel();
  }

  /// 손을 뗀 뒤 10초간 조작이 없으면 자동 넘김 재개.
  void _onUserDragEnd() {
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resumeDelay, () {
      _userInteracting = false;
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _onUserDragStart();
    } else if (n is ScrollEndNotification) {
      _onUserDragEnd();
    }
    return false;
  }

  // ── 다음 곡 ────────────────────────────────────────────────
  Future<void> _playNext() async {
    if (_advancing) return;
    if (_index + 1 >= widget.playlist.length) return;
    _advancing = true;
    try {
      final next = widget.playlist[_index + 1];
      final song = await widget.repo.loadSong(next.id);
      if (!mounted) return;
      setState(() {
        _index += 1;
        _song = song;
        _currentPage = 0;
      });
      if (_pageController.hasClients) _pageController.jumpToPage(0);
      await _player.loadVideoById(videoId: song.youtubeId);
    } finally {
      _advancing = false;
    }
  }

  // ── 공유 ───────────────────────────────────────────────────
  /// "이미지로 보내기" → 문구 수정 화면을 띄운다(거기서 편집 후 공유).
  void _openEditor(GreetingCard card) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditShareScreen(card: card)),
    );
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _resumeTimer?.cancel();
    _player.close();
    _pageController.dispose();
    super.dispose();
  }

  /// 카드 리스트에 광고 슬롯(null)을 interval마다 끼운다.
  List<GreetingCard?> _withCardAds(List<GreetingCard> cards, int interval) {
    final out = <GreetingCard?>[];
    for (var i = 0; i < cards.length; i++) {
      out.add(cards[i]);
      final isLast = i == cards.length - 1;
      if (!isLast && (i + 1) % interval == 0) out.add(null);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = songThemeFor(_song.id);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: theme.gradient),
        child: SafeArea(
          child: Column(
            children: [
              // 상단 바
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 28),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _song.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _song.artist,
                            style: TextStyle(color: theme.accent, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: YoutubePlayer(controller: _player),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.swipe_rounded, color: theme.accent, size: 20),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        '카드가 자동으로 넘어가요 · 넘겨서 골라도 돼요',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 카드 + 광고 페이저
              Expanded(
                child: _song.cards.isEmpty
                    ? const Center(
                        child: Text('준비된 카드가 없어요',
                            style: TextStyle(color: Colors.white54)),
                      )
                    : ValueListenableBuilder<bool>(
                        valueListenable: adsEnabledNotifier,
                        builder: (context, adsOn, _) =>
                            ValueListenableBuilder<int>(
                          valueListenable: cardAdIntervalNotifier,
                          builder: (context, interval, _) {
                            final items = adsOn
                                ? _withCardAds(_song.cards, interval)
                                : List<GreetingCard?>.from(_song.cards);
                            _itemCount = items.length;
                            _lastItems = items;
                            if (_currentPage >= _itemCount) _currentPage = 0;
                            return NotificationListener<ScrollNotification>(
                              onNotification: _onScroll,
                              child: PageView.builder(
                                controller: _pageController,
                                itemCount: items.length,
                                onPageChanged: (i) =>
                                    setState(() => _currentPage = i),
                                itemBuilder: (context, i) {
                                  final card = items[i];
                                  if (card == null) return const CardNativeAd();
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    child: Center(
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        child: GreetingCardView(card: card),
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
              _pageDots(),
              _shareButton(),
              const SizedBox(height: 6),
              // 카드 아래 배너 광고
              const BannerAdBar(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageDots() {
    if (_itemCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_itemCount, (i) {
          final active = i == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: active ? 22 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _shareButton() {
    // 현재 아이템이 광고(null)면 공유 비활성.
    final items = _lastItems;
    final current = (items != null && _currentPage < items.length)
        ? items[_currentPage]
        : null;
    final isAd = current == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: FilledButton.icon(
          onPressed: isAd ? null : () => _openEditor(current),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00704A),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.white24,
            disabledForegroundColor: Colors.white54,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: const Icon(Icons.ios_share_rounded, size: 24),
          label: Text(
            isAd ? '카드를 골라주세요' : '이미지로 보내기',
            style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  // 마지막으로 빌드된 items (공유 버튼이 현재 카드/광고 판별에 사용).
  List<GreetingCard?>? _lastItems;
}
