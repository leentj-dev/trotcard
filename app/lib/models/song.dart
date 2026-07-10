/// 노래 분위기에 맞춰 미리 큐레이션한 "마음 카드" 한 장.
/// 가사는 담지 않는다(저작권). 노래의 느낌·분위기에 어울리는 인사말·명언·
/// 축복 문구를 원본으로 작성해 담는다. 사용자는 이 카드를 이미지로 공유한다.
class GreetingCard {
  /// 카드에 크게 들어갈 문구. 줄바꿈(\n) 포함 가능.
  final String text;

  /// 문구 옆/위에 얹는 이모지 (예: 🌸, ☀️, 💐).
  final String emoji;

  /// 배경 그라데이션 프리셋 키 (card_gradients.dart 참조).
  final String gradient;

  /// 분류: 인사 / 명언 / 축복 / 계절 등. 필터/그룹핑용.
  final String category;

  const GreetingCard({
    required this.text,
    this.emoji = '',
    this.gradient = 'warm',
    this.category = '',
  });

  factory GreetingCard.fromJson(Map<String, dynamic> json) => GreetingCard(
        text: json['text'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '',
        gradient: json['gradient'] as String? ?? 'warm',
        category: json['category'] as String? ?? '',
      );

  GreetingCard copyWith({String? text, String? emoji}) => GreetingCard(
        text: text ?? this.text,
        emoji: emoji ?? this.emoji,
        gradient: gradient,
        category: category,
      );
}

/// 트롯 한 곡 + 그 곡의 분위기에 맞춘 마음 카드 묶음.
class Song {
  final String id;
  final String title;
  final String artist;
  final String youtubeId;

  /// 곡 분위기 메모 (예: "밝고 사랑스러운", "그리움"). 카드 큐레이션 참고용.
  final String mood;

  /// 이 곡을 알린 음악 프로그램 (예: "미스터트롯", "미스트롯"). 정통 트로트
  /// 등 프로그램과 무관한 곡은 빈 문자열.
  final String program;

  final List<GreetingCard> cards;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.youtubeId,
    this.mood = '',
    this.program = '',
    required this.cards,
  });

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String? ?? '',
        youtubeId: json['youtubeId'] as String? ?? '',
        mood: json['mood'] as String? ?? '',
        program: json['program'] as String? ?? '',
        cards: (json['cards'] as List<dynamic>? ?? [])
            .map((c) => GreetingCard.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

/// 피드(노래 목록)용 경량 요약. manifest.json 의 각 항목.
class SongSummary {
  final String id;
  final String title;
  final String artist;
  final String youtubeId;
  final int cardCount;

  /// 이 곡을 알린 음악 프로그램 (예: "미스터트롯"). 없으면 빈 문자열.
  /// 피드에서 프로그램별 그룹핑에 쓰이며, 곡 파일을 받지 않고 판별한다.
  final String program;

  /// 추가 시각(unix 초). 클수록 최신 → 피드 상단.
  final int order;

  /// 곡 파일 내용 해시. 무엇이든 바뀌면 값이 바뀌어 재다운로드 트리거.
  final String hash;

  const SongSummary({
    required this.id,
    required this.title,
    required this.artist,
    required this.youtubeId,
    this.cardCount = 0,
    this.program = '',
    this.order = 0,
    this.hash = '',
  });

  factory SongSummary.fromJson(Map<String, dynamic> json) => SongSummary(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String? ?? '',
        youtubeId: json['youtubeId'] as String? ?? '',
        cardCount: json['cardCount'] as int? ?? 0,
        program: json['program'] as String? ?? '',
        order: json['order'] as int? ?? 0,
        hash: json['hash'] as String? ?? '',
      );
}
