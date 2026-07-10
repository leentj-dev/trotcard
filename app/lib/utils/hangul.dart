/// Hangul syllable decomposition (ported from the web version).
const _initials = [
  'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ',
  'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
];
const _medials = [
  'ㅏ', 'ㅐ', 'ㅑ', 'ㅒ', 'ㅓ', 'ㅔ', 'ㅕ', 'ㅖ', 'ㅗ', 'ㅘ',
  'ㅙ', 'ㅚ', 'ㅛ', 'ㅜ', 'ㅝ', 'ㅞ', 'ㅟ', 'ㅠ', 'ㅡ', 'ㅢ', 'ㅣ',
];
const _finals = [
  '', 'ㄱ', 'ㄲ', 'ㄳ', 'ㄴ', 'ㄵ', 'ㄶ', 'ㄷ', 'ㄹ', 'ㄺ',
  'ㄻ', 'ㄼ', 'ㄽ', 'ㄾ', 'ㄿ', 'ㅀ', 'ㅁ', 'ㅂ', 'ㅄ', 'ㅅ',
  'ㅆ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
];

class HangulChar {
  final String char;
  final List<String> parts;
  const HangulChar(this.char, this.parts);
}

List<HangulChar> decomposeHangul(String text) {
  return text.runes.map((code) {
    final char = String.fromCharCode(code);
    if (code < 0xAC00 || code > 0xD7A3) return HangulChar(char, [char]);
    final offset = code - 0xAC00;
    final initial = _initials[offset ~/ (21 * 28)];
    final medial = _medials[(offset % (21 * 28)) ~/ 28];
    final finale = _finals[offset % 28];
    return HangulChar(
      char,
      finale.isEmpty ? [initial, medial] : [initial, medial, finale],
    );
  }).toList();
}
