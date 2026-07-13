import 'package:flutter/material.dart';

/// 마음 카드 배경으로 쓰는 그라데이션 프리셋.
/// 곡 데이터의 카드가 `gradient` 키로 하나를 고른다. 저작권 걱정 없는
/// 순수 색 그라데이션이라 무한 생성/변주 가능.
class CardGradient {
  final LinearGradient gradient;

  /// 이 배경 위 글씨/이모지에 어울리는 전경색.
  final Color foreground;

  const CardGradient(this.gradient, this.foreground);
}

const _presets = <String, CardGradient>{
  // 따뜻한 살구빛 — 사랑/설렘
  'warm': CardGradient(
    LinearGradient(
      colors: [Color(0xFFFF9A8B), Color(0xFFFF6A88), Color(0xFFFF99AC)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    Colors.white,
  ),
  // 해돋이 — 아침 인사/희망
  'sunrise': CardGradient(
    LinearGradient(
      colors: [Color(0xFFFFE29F), Color(0xFFFFA99F), Color(0xFFFF719A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    Color(0xFF5A2A2A),
  ),
  // 봄날 새순 — 건강/생기
  'spring': CardGradient(
    LinearGradient(
      colors: [Color(0xFFC1F0C8), Color(0xFF9BE7B4), Color(0xFF7CD9C1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    Color(0xFF204A3A),
  ),
  // 잔잔한 하늘빛 — 위로/평안
  'calm': CardGradient(
    LinearGradient(
      colors: [Color(0xFFA1C4FD), Color(0xFFC2E9FB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    Color(0xFF20335A),
  ),
  // 노을·저녁 — 그리움/추억
  'sunset': CardGradient(
    LinearGradient(
      colors: [Color(0xFFF6D365), Color(0xFFFDA085), Color(0xFFEC6F66)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    Colors.white,
  ),
  // 밤·별 — 편안한 저녁 인사
  'night': CardGradient(
    LinearGradient(
      colors: [Color(0xFF30336B), Color(0xFF535C9B), Color(0xFF6D5B97)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    Colors.white,
  ),
  // 장미빛 — 축복/감사
  'rose': CardGradient(
    LinearGradient(
      colors: [Color(0xFFE55D87), Color(0xFFE0669A), Color(0xFFF78CA0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    Colors.white,
  ),
  // 라벤더 — 우아함/차분한 인사
  'lavender': CardGradient(
    LinearGradient(
      colors: [Color(0xFFD9AFD9), Color(0xFFC3A0E8), Color(0xFF97D9E1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    Color(0xFF3A2A55),
  ),
  // 동물 — 포근한 크림빛 (사진 로딩 폴백)
  'animal': CardGradient(
    LinearGradient(
      colors: [Color(0xFFFAD9A0), Color(0xFFF6B98A), Color(0xFFE8A87C)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    Colors.white,
  ),
  // 카페 — 따뜻한 커피빛
  'cafe': CardGradient(
    LinearGradient(
      colors: [Color(0xFFC9A27E), Color(0xFFA9754F), Color(0xFF7B4B2A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    Colors.white,
  ),
  // 도서관 — 고요한 우드빛
  'library': CardGradient(
    LinearGradient(
      colors: [Color(0xFFD8B98C), Color(0xFFB08850), Color(0xFF6E4A2A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    Colors.white,
  ),
};

/// 키로 프리셋을 찾고, 없으면 warm 으로 폴백.
CardGradient cardGradientFor(String key) =>
    _presets[key] ?? _presets['warm']!;

/// 모든 프리셋 키 (에디터/미리보기용).
List<String> get cardGradientKeys => _presets.keys.toList();
