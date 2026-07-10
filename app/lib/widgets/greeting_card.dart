import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import '../models/song.dart';
import '../utils/card_gradients.dart';

/// 이 APK 번들에 실제로 들어있는 분위기별 사진 수 (`assets/bg/{key}_1..N.jpg`).
/// 이 값 이하 인덱스는 번들 asset, 초과 인덱스는 GitHub raw에서 받아 캐시(OTA).
const _bundledBgCount = {
  'warm': 24, 'sunrise': 21, 'spring': 22, 'calm': 25,
  'sunset': 25, 'night': 21, 'rose': 24, 'lavender': 27,
};

/// 원격 bg_manifest.json 로 갱신되는 분위기별 사진 수. 세션 중에는 고정
/// (같은 카드=항상 같은 사진). 최신값은 prefs 에 캐시돼 다음 실행에 반영된다.
final bgCountsNotifier =
    ValueNotifier<Map<String, int>>(Map.of(_bundledBgCount));

const _bgCountsPrefsKey = 'bg_counts';

/// 앱 시작 시 호출: prefs 캐시된 원격 장수를 즉시 적용(세션 안정)하고,
/// 백그라운드로 최신 bg_manifest.json 을 받아 prefs 만 갱신(다음 실행 반영).
Future<void> loadBgCounts() async {
  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString(_bgCountsPrefsKey);
  if (cached != null) {
    try {
      final m = (jsonDecode(cached) as Map)
          .map((k, v) => MapEntry(k as String, (v as num).toInt()));
      bgCountsNotifier.value = {..._bundledBgCount, ...m};
    } catch (_) {}
  }
  _refreshBgManifest(prefs); // 대기하지 않음
}

Future<void> _refreshBgManifest(SharedPreferences prefs) async {
  try {
    final res = await http
        .get(Uri.parse('${appConfig.bgRemoteBase}/bg_manifest.json'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final m = (jsonDecode(res.body) as Map)
          .map((k, v) => MapEntry(k as String, (v as num).toInt()));
      await prefs.setString(_bgCountsPrefsKey, jsonEncode(m));
    }
  } catch (_) {
    // 오프라인 등 실패 시 조용히 무시(번들/이전 캐시 유지).
  }
}

/// 문자열 안정 해시 (Dart String.hashCode는 런마다 달라질 수 있어 직접 계산).
int _stableHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

/// 카드마다 분위기 풀에서 고정된 사진 인덱스(1..N)를 고른다. N은 원격 장수.
int bgIndexFor(GreetingCard card) {
  final n = bgCountsNotifier.value[card.gradient] ??
      _bundledBgCount[card.gradient] ??
      1;
  return _stableHash(card.text) % n + 1;
}

/// 배경 사진 위젯: 번들 범위면 asset, 넘으면 GitHub raw(디스크 캐시).
Widget bgImage(String gradientKey, int idx, {BoxFit fit = BoxFit.cover}) {
  final bundled = _bundledBgCount[gradientKey] ?? 0;
  if (idx <= bundled) {
    return Image.asset('assets/bg/${gradientKey}_$idx.jpg',
        fit: fit, errorBuilder: (_, _, _) => const SizedBox.shrink());
  }
  return CachedNetworkImage(
    imageUrl: '${appConfig.bgRemoteBase}/${gradientKey}_$idx.jpg',
    fit: fit,
    fadeInDuration: const Duration(milliseconds: 200),
    placeholder: (_, _) => const SizedBox.shrink(),
    errorWidget: (_, _, _) => const SizedBox.shrink(),
  );
}

/// 원격 사진의 공유 캡처 전 미리 로드(캐시). 번들 범위면 즉시 반환.
Future<void> precacheBg(BuildContext context, String gradientKey, int idx) async {
  if (idx <= (_bundledBgCount[gradientKey] ?? 0)) return;
  try {
    await precacheImage(
      CachedNetworkImageProvider(
          '${appConfig.bgRemoteBase}/${gradientKey}_$idx.jpg'),
      context,
    );
  } catch (_) {}
}

/// 마음 카드의 순수 비주얼. 그리드 타일·전체보기·공유 캡처에 공통으로 쓴다.
/// 정사각형(1:1) — 카톡 공유 이미지에 잘 맞는 비율.
class GreetingCardView extends StatelessWidget {
  final GreetingCard card;

  /// 하단 브랜드 워터마크 표시 여부 (공유 이미지엔 표시, 필요 시 숨김).
  final bool showBrand;

  /// 배경 사진 인덱스 고정용(편집 미리보기에서 사진이 안 바뀌게). null이면
  /// 카드 텍스트 해시로 자동 선택.
  final int? bgIndex;

  const GreetingCardView({
    super.key,
    required this.card,
    this.showBrand = true,
    this.bgIndex,
  });

  @override
  Widget build(BuildContext context) {
    final g = cardGradientFor(card.gradient);
    const shadow = [
      Shadow(color: Color(0xCC000000), blurRadius: 12, offset: Offset(0, 2)),
      Shadow(color: Color(0x99000000), blurRadius: 24),
    ];
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, c) {
          final s = c.maxWidth; // 정사각형 한 변
          return Container(
            // 사진 로딩 전/누락 시 폴백 그라데이션.
            decoration: BoxDecoration(gradient: g.gradient),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 실사 자연/꽃 배경 사진 (분위기 풀에서 카드별 고정 선택)
                bgImage(card.gradient, bgIndex ?? bgIndexFor(card)),
                // 가독성 스크림: 전체 살짝 + 가운데만 은은하게 (배경 잘 보이게)
                Container(color: const Color(0x1A000000)),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.9,
                      colors: [Color(0x55000000), Color(0x00000000)],
                    ),
                  ),
                ),
                // 문구
                Padding(
                  padding: EdgeInsets.all(s * 0.10),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (card.emoji.isNotEmpty)
                              Text(card.emoji,
                                  style: const TextStyle(fontSize: 52)),
                            if (card.emoji.isNotEmpty)
                              const SizedBox(height: 16),
                            Text(
                              card.text,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                                height: 1.4,
                                shadows: shadow,
                              ),
                            ),
                            if (showBrand) ...[
                              const SizedBox(height: 20),
                              Text(
                                '💌 트로트 카드',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  shadows: shadow,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// [boundaryKey] 로 감싼 카드를 PNG 로 캡처해 시스템 공유 시트로 내보낸다.
/// 카톡·문자·사진첩 등 사용자가 고른 앱으로 이미지가 전달된다.
Future<void> shareCardImage(GlobalKey boundaryKey, {String? text}) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 3.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return;

  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/trotcard_${DateTime.now().millisecondsSinceEpoch}.png');
  await file.writeAsBytes(bytes.buffer.asUint8List());

  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: text),
  );
}

/// 카드 위에 붙이는 스티커(이모지) 한 개.
class _Sticker {
  String emoji;
  Offset pos; // 카드 한 변 기준 0~1 (중심 앵커)
  double scale;
  _Sticker(this.emoji, this.pos, this.scale);
}

/// 이미지 편집·공유 화면.
/// - 문구는 카드 위에서 바로 수정(별도 입력칸 없음).
/// - 아래 가로 스크롤 팔레트에서 스티커를 붙이고, 드래그로 옮기고,
///   크게/작게/삭제할 수 있다.
/// - 키보드가 떠도 카드가 위로 밀려 사라지지 않는다(resize 안 함).
class EditShareScreen extends StatefulWidget {
  final GreetingCard card;

  const EditShareScreen({super.key, required this.card});

  @override
  State<EditShareScreen> createState() => _EditShareScreenState();
}

class _EditShareScreenState extends State<EditShareScreen> {
  final _boundaryKey = GlobalKey();
  late final TextEditingController _controller;
  late final int _bgIdx;
  final List<_Sticker> _stickers = [];
  int? _selected;
  bool _sharing = false;

  static const _palette = [
    '🌸','❤️','🎉','😊','👍','🌷','🌹','✨','🥰','💐',
    '🍀','🎈','🌻','🎁','💕','⭐','🙏','🎶','🌺','💖',
  ];

  static const _shadow = [
    Shadow(color: Color(0xCC000000), blurRadius: 12, offset: Offset(0, 2)),
    Shadow(color: Color(0x99000000), blurRadius: 24),
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.card.text);
    _bgIdx = bgIndexFor(widget.card);
    // 카드 원래 이모지도 스티커로 시작 → 이동·크기·삭제 가능.
    if (widget.card.emoji.isNotEmpty) {
      _stickers.add(_Sticker(widget.card.emoji, const Offset(0.5, 0.24), 1.2));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addSticker(String e) {
    setState(() {
      _stickers.add(_Sticker(e, const Offset(0.5, 0.45), 1));
      _selected = _stickers.length - 1;
    });
  }

  void _scaleSel(double f) {
    final i = _selected;
    if (i != null) {
      setState(() =>
          _stickers[i].scale = (_stickers[i].scale * f).clamp(0.4, 3.5));
    }
  }

  void _deleteSel() {
    final i = _selected;
    if (i != null) {
      setState(() {
        _stickers.removeAt(i);
        _selected = null;
      });
    }
  }

  Future<void> _share() async {
    if (_sharing) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _selected = null; // 선택 테두리 제거 후 캡처
      _sharing = true;
    });
    // 원격 배경이면 캡처 전에 로드(캐시)해 이미지가 빠지지 않게.
    await precacheBg(context, widget.card.gradient, _bgIdx);
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      await shareCardImage(_boundaryKey);
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
  Widget build(BuildContext context) {
    final g = cardGradientFor(widget.card.gradient);
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false, // 키보드가 떠도 카드가 안 밀리게
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 30),
              ),
            ),
            // ── 편집 카드 (맨 위로 붙임 → 키보드 떠도 전체 보임) ──
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final side = c.maxWidth;
                            return Stack(
                              children: [
                                Positioned.fill(
                                  child: DecoratedBox(
                                      decoration:
                                          BoxDecoration(gradient: g.gradient)),
                                ),
                                Positioned.fill(
                                  child: bgImage(widget.card.gradient, _bgIdx),
                                ),
                                Positioned.fill(
                                  child: Container(
                                      color: const Color(0x1A000000)),
                                ),
                                const Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        radius: 0.9,
                                        colors: [
                                          Color(0x55000000),
                                          Color(0x00000000)
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // 빈 곳 탭 → 선택 해제
                                Positioned.fill(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () =>
                                        setState(() => _selected = null),
                                  ),
                                ),
                                // 문구(제자리 편집) — 카드 가운데
                                Padding(
                                  padding: EdgeInsets.all(side * 0.09),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                          maxWidth: side * 0.82),
                                      child: TextField(
                                        controller: _controller,
                                        maxLines: null,
                                        textAlign: TextAlign.center,
                                        cursorColor: Colors.white,
                                        onTap: () => setState(
                                            () => _selected = null),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: side * 0.078,
                                          fontWeight: FontWeight.w800,
                                          height: 1.35,
                                          shadows: _shadow,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                          hintText: '문구 입력',
                                          hintStyle:
                                              TextStyle(color: Colors.white38),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // 브랜드 — 카드 맨 하단
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: side * 0.06,
                                  child: Text('💌 트로트 카드',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.85),
                                        fontSize: side * 0.036,
                                        fontWeight: FontWeight.w700,
                                        shadows: _shadow,
                                      )),
                                ),
                                // 스티커들
                                for (int i = 0; i < _stickers.length; i++)
                                  _stickerWidget(i, side),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // ── 스티커 팔레트 (기존 문구 자리, 가로 스크롤) ──
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _palette.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => _addSticker(_palette[i]),
                  child: Container(
                    width: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(_palette[i],
                        style: const TextStyle(fontSize: 28)),
                  ),
                ),
              ),
            ),
            // ── 선택된 스티커 조절 ──
            if (_selected != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ctrlBtn('작게', Icons.remove_rounded, () => _scaleSel(0.85)),
                    _ctrlBtn('크게', Icons.add_rounded, () => _scaleSel(1.18)),
                    _ctrlBtn('삭제', Icons.delete_outline_rounded, _deleteSel,
                        color: const Color(0xFFE11D48)),
                  ],
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('문구를 눌러 고치고, 스티커를 붙여보세요',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
              ),
            // ── 보내기 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton.icon(
                  onPressed: _sharing ? null : _share,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00704A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: _sharing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Icon(Icons.ios_share_rounded, size: 24),
                  label: const Text('이미지로 보내기',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ctrlBtn(String label, IconData icon, VoidCallback onTap,
      {Color color = const Color(0xFF3A3A3C)}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton.icon(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          icon: Icon(icon, size: 20),
          label: Text(label,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _stickerWidget(int i, double side) {
    final s = _stickers[i];
    final sel = _selected == i;
    final fs = side * 0.14 * s.scale;
    return Positioned(
      left: s.pos.dx * side - fs * 0.62,
      top: s.pos.dy * side - fs * 0.62,
      child: GestureDetector(
        onTap: () => setState(() => _selected = i),
        onPanStart: (_) {
          if (_selected != i) setState(() => _selected = i);
        },
        onPanUpdate: (d) => setState(() {
          s.pos = Offset(
            (s.pos.dx + d.delta.dx / side).clamp(0.03, 0.97),
            (s.pos.dy + d.delta.dy / side).clamp(0.03, 0.97),
          );
        }),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: sel
              ? BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(10),
                )
              : null,
          child: Text(s.emoji, style: TextStyle(fontSize: fs, shadows: _shadow)),
        ),
      ),
    );
  }
}
