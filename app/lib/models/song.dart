class WordEntry {
  final String korean;
  final String romanization;
  final String english;
  final String spanish;
  final String portuguese;
  final String indonesian;
  final String japanese;
  final String korean_;
  final String thai;
  final String french;
  final String partOfSpeech;
  final String emoji;
  final String example;
  final String exampleTranslation;
  final double? timestamp;

  const WordEntry({
    required this.korean,
    required this.romanization,
    required this.english,
    this.spanish = '',
    this.portuguese = '',
    this.indonesian = '',
    this.japanese = '',
    this.korean_ = '',
    this.thai = '',
    this.french = '',
    this.partOfSpeech = '',
    this.emoji = '',
    this.example = '',
    this.exampleTranslation = '',
    this.timestamp,
  });

  factory WordEntry.fromJson(Map<String, dynamic> json) => WordEntry(
        korean: json['korean'] as String? ?? '',
        romanization: json['romanization'] as String? ?? '',
        english: json['english'] as String? ?? '',
        spanish: json['spanish'] as String? ?? '',
        portuguese: json['portuguese'] as String? ?? '',
        indonesian: json['indonesian'] as String? ?? '',
        japanese: json['japanese'] as String? ?? '',
        korean_: json['koreanTranslation'] as String? ?? '',
        thai: json['thai'] as String? ?? '',
        french: json['french'] as String? ?? '',
        partOfSpeech: json['partOfSpeech'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '',
        example: json['example'] as String? ?? '',
        exampleTranslation: json['exampleTranslation'] as String? ?? '',
        timestamp: (json['timestamp'] as num?)?.toDouble(),
      );

  /// Translation for the given language code, falling back to English.
  String translation(String lang) {
    final value = switch (lang) {
      'spanish' => spanish,
      'portuguese' => portuguese,
      'indonesian' => indonesian,
      'japanese' => japanese,
      'korean' => korean_,
      'thai' => thai,
      'french' => french,
      _ => english,
    };
    return value.isEmpty ? english : value;
  }
}

class Song {
  final String id;
  final String title;
  final String artist;
  final String youtubeId;

  /// Seconds the music video runs ahead of the audio track (e.g. a drama
  /// intro before the song starts). Word timestamps are audio-relative, so
  /// video time = timestamp + introOffset. Data default 0; the user can
  /// nudge it live and that override is stored per-song on device.
  final double introOffset;

  final List<WordEntry> words;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.youtubeId,
    this.introOffset = 0,
    required this.words,
  });

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String? ?? '',
        youtubeId: json['youtubeId'] as String? ?? '',
        introOffset: (json['introOffset'] as num?)?.toDouble() ?? 0,
        words: (json['words'] as List<dynamic>? ?? [])
            .map((w) => WordEntry.fromJson(w as Map<String, dynamic>))
            .toList(),
      );

  bool get isSynced => words.where((w) => w.timestamp != null).length >= 10;
}

class SongSummary {
  final String id;
  final String title;
  final String artist;
  final String youtubeId;
  final bool synced;
  final int wordCount;

  /// When the song was first added (unix seconds). Newer = larger; the feed
  /// sorts descending so the most recently added song is on top.
  final int order;

  /// Content hash of the song file (from the manifest). Any change to the song
  /// (words, translations, timestamps, offset, ...) changes this, which is how
  /// [SongRepository] detects that a song needs re-downloading. Empty for old
  /// manifests that predate the hash field (falls back to field comparison).
  final String hash;

  const SongSummary({
    required this.id,
    required this.title,
    required this.artist,
    required this.youtubeId,
    required this.synced,
    required this.wordCount,
    this.order = 0,
    this.hash = '',
  });

  factory SongSummary.fromJson(Map<String, dynamic> json) => SongSummary(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String? ?? '',
        youtubeId: json['youtubeId'] as String? ?? '',
        synced: json['synced'] as bool? ?? false,
        wordCount: json['wordCount'] as int? ?? 0,
        order: json['order'] as int? ?? 0,
        hash: json['hash'] as String? ?? '',
      );
}
