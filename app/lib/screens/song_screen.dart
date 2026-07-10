import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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

  /// 카드 사이 네이티브 광고 로더 풀. PageView 밖에서 미리 로드해두고,
  /// **로드된 광고만** 슬롯으로 끼운다(로드 안 된 슬롯은 안 만들어 빈 페이지 방지).
  final List<CardNativeAdLoader> _adLoaders = [];

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
    cardAutoSecNotifier.addListener(_startAuto); // RC로 속도 바뀌면 타이머 재시작
    _syncAdPool();
    cardAdIntervalNotifier.addListener(_syncAdPool);
    adsEnabledNotifier.addListener(_syncAdPool);
  }

  /// 현재 곡·간격에서 필요한 광고 슬롯 개수만큼 로더를 확보한다.
  /// 로더 생성 자체는 화면에 영향이 없고(광고는 비동기 로드), 로드 완료 시
  /// [_onAdChanged] 가 rebuild 하므로 여기선 setState 하지 않는다(initState 안전).
  void _syncAdPool() {
    final need = adsEnabledNotifier.value
        ? _neededAdSlots(cardAdIntervalNotifier.value)
        : 0;
    while (_adLoaders.length < need) {
      _adLoaders.add(CardNativeAdLoader()..addListener(_onAdChanged));
    }
  }

  int _neededAdSlots(int interval) {
    final n = _song.cards.length;
    var slots = 0;
    for (var i = 0; i < n; i++) {
      final isLast = i == n - 1;
      if (!isLast && (i + 1) % interval == 0) slots++;
    }
    return slots;
  }

  void _onAdChanged() {
    if (mounted) setState(() {});
  }

  // ── 자동 넘김 ──────────────────────────────────────────────
  void _startAuto() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(
        Duration(seconds: cardAutoSecNotifier.value), (_) => _autoAdvance());
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

  /// 손을 뗀 뒤 일정 시간 조작이 없으면 자동 넘김 재개(`card_resume_sec`).
  void _onUserDragEnd() {
    _resumeTimer?.cancel();
    _resumeTimer = Timer(Duration(seconds: cardResumeSecNotifier.value), () {
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
      _syncAdPool(); // 새 곡의 카드 수에 맞춰 광고 슬롯 보충
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
    cardAutoSecNotifier.removeListener(_startAuto);
    cardAdIntervalNotifier.removeListener(_syncAdPool);
    adsEnabledNotifier.removeListener(_syncAdPool);
    for (final l in _adLoaders) {
      l.removeListener(_onAdChanged);
      l.dispose();
    }
    _autoTimer?.cancel();
    _resumeTimer?.cancel();
    _player.close();
    _pageController.dispose();
    super.dispose();
  }

  /// 카드 리스트에 **로드된** 광고를 interval마다 끼운다. 아직 로드 안 된
  /// 슬롯은 건너뛰어(빈 페이지 방지) 광고가 준비된 만큼만 노출한다.
  /// 반환 원소: [GreetingCard] 또는 [NativeAd].
  List<Object> _withCardAds(List<GreetingCard> cards, int interval) {
    final loaded = <NativeAd>[
      for (final l in _adLoaders)
        if (l.ad != null) l.ad!,
    ];
    final out = <Object>[];
    var adIdx = 0;
    for (var i = 0; i < cards.length; i++) {
      out.add(cards[i]);
      final isLast = i == cards.length - 1;
      if (!isLast && (i + 1) % interval == 0 && adIdx < loaded.length) {
        out.add(loaded[adIdx++]);
      }
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
              // 카드 + 광고 페이저 (+ 인디케이터·공유버튼·배너)
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
                                : List<Object>.from(_song.cards);
                            _itemCount = items.length;
                            if (_currentPage >= _itemCount) _currentPage = 0;
                            final currentItem = _currentPage < items.length
                                ? items[_currentPage]
                                : null;
                            final current = currentItem is GreetingCard
                                ? currentItem
                                : null;
                            return Column(
                              children: [
                                Expanded(
                                  child:
                                      NotificationListener<ScrollNotification>(
                                    onNotification: _onScroll,
                                    child: PageView.builder(
                                      controller: _pageController,
                                      itemCount: items.length,
                                      onPageChanged: (i) =>
                                          setState(() => _currentPage = i),
                                      itemBuilder: (context, i) {
                                        final item = items[i];
                                        if (item is NativeAd) {
                                          return CardNativeAdView(ad: item);
                                        }
                                        final card = item as GreetingCard;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 8),
                                          child: Center(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              child:
                                                  GreetingCardView(card: card),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                _pageDots(items.length),
                                _shareButton(current),
                                const SizedBox(height: 6),
                                const BannerAdBar(),
                                const SizedBox(height: 8),
                              ],
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageDots(int count) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
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

  Widget _shareButton(GreetingCard? current) {
    // 현재 아이템이 광고(null)면 공유 비활성.
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
}
