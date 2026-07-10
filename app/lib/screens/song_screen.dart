import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../data/song_repository.dart';
import '../models/song.dart';
import '../utils/themes.dart';
import '../widgets/greeting_card.dart';
import '../widgets/native_ad_card.dart';

/// 노래 상세 — 위에 유튜브로 트롯을 재생하며, 아래에서 그 곡의 분위기에
/// 맞춘 "마음 카드"를 골라 이미지로 공유한다.
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
  late Song _song;
  late int _index;
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    _song = widget.song;
    _index = widget.index;
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
      });
      await _player.loadVideoById(videoId: song.youtubeId);
    } finally {
      _advancing = false;
    }
  }

  void _openCard(GreetingCard card) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullCardScreen(card: card, songTitle: _song.title),
      ),
    );
  }

  @override
  void dispose() {
    _player.close();
    super.dispose();
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
              // 유튜브 플레이어
              AspectRatio(
                aspectRatio: 16 / 9,
                child: YoutubePlayer(controller: _player),
              ),
              // 안내
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.favorite_rounded,
                        color: theme.accent, size: 20),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        '마음에 드는 카드를 눌러 친구에게 보내보세요',
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
              // 카드 그리드
              Expanded(
                child: _song.cards.isEmpty
                    ? const Center(
                        child: Text('준비된 카드가 없어요',
                            style: TextStyle(color: Colors.white54)),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1,
                        ),
                        itemCount: _song.cards.length,
                        itemBuilder: (context, i) {
                          final card = _song.cards[i];
                          return GestureDetector(
                            onTap: () => _openCard(card),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: GreetingCardView(
                                  card: card, showBrand: false),
                            ),
                          );
                        },
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
