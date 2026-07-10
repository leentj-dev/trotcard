import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../data/song_repository.dart';
import '../models/song.dart';
import '../utils/themes.dart';
import '../widgets/greeting_card.dart';
import '../widgets/native_ad_card.dart';

/// 노래 상세 — 위에 유튜브로 트롯을 재생하며, 아래에서 그 곡의 분위기에
/// 맞춘 "마음 카드"를 한 장씩 넘겨 보고 이미지로 공유한다.
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

  /// 현재 보이는 카드 인덱스.
  int _currentCard = 0;

  /// 공유 캡처용 — 카드마다 RepaintBoundary 키 하나.
  late List<GlobalKey> _cardKeys;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _song = widget.song;
    _index = widget.index;
    _cardKeys = _makeKeys(_song.cards.length);
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
  }

  List<GlobalKey> _makeKeys(int n) =>
      List.generate(n, (_) => GlobalKey());

  /// 영상이 끝나면 목록의 다음 곡으로 자동 이동.
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
        _currentCard = 0;
        _cardKeys = _makeKeys(song.cards.length);
      });
      if (_pageController.hasClients) _pageController.jumpToPage(0);
      await _player.loadVideoById(videoId: song.youtubeId);
    } finally {
      _advancing = false;
    }
  }

  /// 현재 보이는 카드를 이미지로 공유.
  Future<void> _shareCurrent() async {
    if (_sharing || _song.cards.isEmpty) return;
    setState(() => _sharing = true);
    try {
      await shareCardImage(_cardKeys[_currentCard]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공유에 실패했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  void dispose() {
    _player.close();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = songThemeFor(_song.id);
    final cards = _song.cards;
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
              // 유튜브 플레이어
              AspectRatio(
                aspectRatio: 16 / 9,
                child: YoutubePlayer(controller: _player),
              ),
              // 안내
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.swipe_rounded, color: theme.accent, size: 20),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        '옆으로 넘겨 마음에 드는 카드를 고르세요',
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
              // 카드 한 장씩 (좌우 스와이프)
              Expanded(
                child: cards.isEmpty
                    ? const Center(
                        child: Text('준비된 카드가 없어요',
                            style: TextStyle(color: Colors.white54)),
                      )
                    : PageView.builder(
                        controller: _pageController,
                        itemCount: cards.length,
                        onPageChanged: (i) =>
                            setState(() => _currentCard = i),
                        itemBuilder: (context, i) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            child: Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                // 이 RepaintBoundary 안이 곧 공유 이미지.
                                child: RepaintBoundary(
                                  key: _cardKeys[i],
                                  child: GreetingCardView(card: cards[i]),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              // 페이지 인디케이터
              if (cards.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(cards.length, (i) {
                      final active = i == _currentCard;
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
                ),
              // 공유 버튼 (현재 카드)
              if (cards.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: FilledButton.icon(
                      onPressed: _sharing ? null : _shareCurrent,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00704A), // 스타벅스 그린
                        foregroundColor: Colors.white, // 글자·아이콘 흰색
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: _sharing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Icon(Icons.ios_share_rounded, size: 24),
                      label: const Text(
                        '이미지로 보내기',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              const NativeAdCard(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
