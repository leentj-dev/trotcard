import '../models/song.dart';
import '../utils/hangul.dart';

/// Strategy for the language being *learned* (Korean, Japanese, Spanish…).
///
/// Each flavor of the app plugs in one of these. The song JSON schema is
/// shared — the headword lives in `WordEntry.korean` regardless of flavor —
/// so only the per-character breakdown and TTS locale differ.
abstract class TargetLanguage {
  const TargetLanguage();

  /// TTS locale for reading the headword aloud, e.g. 'ko-KR', 'ja-JP'.
  String get ttsLocale;

  /// UI translation language keys valid for this target (see
  /// utils/languages.dart). Excludes the target's own language — it makes
  /// no sense to "translate" the headword into the language it already is.
  List<String> get uiLanguages;

  /// Sub-unit chips shown under the headword (Korean jamo, Japanese
  /// furigana…). Return an empty list to hide the breakdown row.
  List<String> breakdown(WordEntry word);
}

const _defaultUiLanguages = [
  'english',
  'spanish',
  'portuguese',
  'indonesian',
  'thai',
  'french',
];

/// Korean: decompose each syllable into its jamo (ㅂ + ㅗ + ㄴ).
class KoreanTarget extends TargetLanguage {
  const KoreanTarget();

  @override
  String get ttsLocale => 'ko-KR';

  @override
  List<String> get uiLanguages => const [..._defaultUiLanguages, 'japanese'];

  @override
  List<String> breakdown(WordEntry word) {
    return decomposeHangul(word.korean)
        .where((c) => c.parts.length > 1)
        .map((c) => c.parts.join(' + '))
        .toList();
  }
}

/// Japanese: show the kana reading (furigana) when the headword has kanji.
/// `WordEntry.japanese` is repurposed to hold that reading for this flavor
/// (it isn't needed as a translation slot — the headword already is
/// Japanese) — content packs must fill it with the word's kana reading.
class JapaneseTarget extends TargetLanguage {
  const JapaneseTarget();

  static const _kanjiRange = (0x4E00, 0x9FFF);

  @override
  String get ttsLocale => 'ja-JP';

  @override
  List<String> get uiLanguages => const [..._defaultUiLanguages, 'korean'];

  @override
  List<String> breakdown(WordEntry word) {
    final hasKanji = word.korean.runes
        .any((r) => r >= _kanjiRange.$1 && r <= _kanjiRange.$2);
    final reading = word.japanese.trim();
    if (!hasKanji || reading.isEmpty || reading == word.korean) return const [];
    return [reading];
  }
}

/// Spanish and other romanized languages: no sub-unit breakdown needed.
class RomanTarget extends TargetLanguage {
  final String locale;
  const RomanTarget(this.locale);

  @override
  String get ttsLocale => locale;

  @override
  List<String> get uiLanguages => const [..._defaultUiLanguages, 'korean'];

  @override
  List<String> breakdown(WordEntry word) => const [];
}
