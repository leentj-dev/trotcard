import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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
  'sunrise': 24, 'spring': 22, 'calm': 38,
  'sunset': 34, 'night': 24, 'rose': 24, 'lavender': 27,
  'animal': 27, 'cafe': 15, 'library': 11,
};

/// 원격 bg_manifest.json 로 갱신되는 분위기별 사진 수. (같은 카드=항상 같은 사진)
final bgCountsNotifier =
    ValueNotifier<Map<String, int>>(Map.of(_bundledBgCount));

/// 원격 배경 사진을 로컬로 내려받는 중인지 — 피드에서 "사진 받는 중" 표시용.
final bgDownloadingNotifier = ValueNotifier<bool>(false);

const _bgCountsPrefsKey = 'bg_counts';

// 다운로드된 원격 배경 저장 폴더 + 보유 목록('key_idx'). 존재 여부로 비교.
Directory? _bgDir;
final Set<String> _localBg = {};

Future<Directory> _ensureBgDir() async {
  if (_bgDir != null) return _bgDir!;
  final docs = await getApplicationDocumentsDirectory();
  final d = Directory('${docs.path}/bg');
  if (!d.existsSync()) d.createSync(recursive: true);
  // 이미 받아둔 파일을 메모리 목록에 적재(빠른 존재 확인).
  for (final f in d.listSync()) {
    final n = f.uri.pathSegments.last;
    if (n.endsWith('.jpg')) _localBg.add(n.substring(0, n.length - 4));
  }
  _bgDir = d;
  return d;
}

/// 앱 시작 시: 로컬 폴더 준비 + prefs 캐시 개수 즉시 적용, 백그라운드로 동기화.
Future<void> loadBgCounts() async {
  await _ensureBgDir();
  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString(_bgCountsPrefsKey);
  if (cached != null) {
    try {
      final m = (jsonDecode(cached) as Map)
          .map((k, v) => MapEntry(k as String, (v as num).toInt()));
      bgCountsNotifier.value = {..._bundledBgCount, ...m};
    } catch (_) {}
  }
  syncRemoteBgImages(); // 대기하지 않음(백그라운드)
}

/// 원격 bg_manifest 와 비교해 **로컬에 없는 사진만** 내려받아 로컬에 저장한다.
/// 개수 차이가 아니라 '파일이 있나 없나'로 판단 → 앞으로 사진을 추가하면 자동 반영.
/// 한 번 받으면 이후엔 로컬에서 로드(매번 네트워크 조회 아님).
Future<void> syncRemoteBgImages() async {
  Map<String, int> counts;
  try {
    final res = await http
        .get(Uri.parse('${appConfig.bgRemoteBase}/bg_manifest.json'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return;
    counts = (jsonDecode(res.body) as Map)
        .map((k, v) => MapEntry(k as String, (v as num).toInt()));
  } catch (_) {
    return; // 오프라인 등 → 번들/기존 캐시 유지
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_bgCountsPrefsKey, jsonEncode(counts));
  bgCountsNotifier.value = {..._bundledBgCount, ...counts};

  // 번들 초과 인덱스 중 로컬에 없는 파일만 목록화.
  final dir = await _ensureBgDir();
  final missing = <String>[];
  counts.forEach((key, n) {
    final bundled = _bundledBgCount[key] ?? 0;
    for (var idx = bundled + 1; idx <= n; idx++) {
      final name = '${key}_$idx';
      if (!_localBg.contains(name)) missing.add(name);
    }
  });
  if (missing.isEmpty) return;

  bgDownloadingNotifier.value = true;
  try {
    for (final name in missing) {
      try {
        final r = await http
            .get(Uri.parse('${appConfig.bgRemoteBase}/$name.jpg'))
            .timeout(const Duration(seconds: 20));
        if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
          File('${dir.path}/$name.jpg').writeAsBytesSync(r.bodyBytes);
          _localBg.add(name);
        }
      } catch (_) {}
    }
  } finally {
    bgDownloadingNotifier.value = false;
    // 새로 받은 사진이 화면에 반영되도록 리빌드 트리거.
    bgCountsNotifier.value = Map.of(bgCountsNotifier.value);
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

/// 사진이 0장인 분위기(예: 제거된 warm)는 대체 풀로 매핑해 카드가 깨지지 않게 한다.
String effectiveBgKey(String key) {
  final n = bgCountsNotifier.value[key] ?? _bundledBgCount[key] ?? 0;
  return n > 0 ? key : 'sunset';
}

/// 카드마다 분위기 풀에서 고정된 사진 인덱스(1..N)를 고른다. N은 원격 장수.
int bgIndexFor(GreetingCard card) {
  final key = effectiveBgKey(card.gradient);
  final n = bgCountsNotifier.value[key] ?? _bundledBgCount[key] ?? 1;
  return _stableHash(card.text) % n + 1;
}

/// 분위기 풀 크기(1..N). 편집 화면에서 배경을 좌우로 넘겨 고를 때 상한.
int bgPoolSize(String gradientKey) {
  final key = effectiveBgKey(gradientKey);
  return bgCountsNotifier.value[key] ?? _bundledBgCount[key] ?? 1;
}

/// 배경 사진 위젯: 번들이면 asset, 받아둔 원격은 로컬 파일, 아직이면 원격 폴백.
Widget bgImage(String gradientKey, int idx, {BoxFit fit = BoxFit.cover}) {
  final key = effectiveBgKey(gradientKey);
  final bundled = _bundledBgCount[key] ?? 0;
  if (idx <= bundled) {
    return Image.asset('assets/bg/${key}_$idx.jpg',
        fit: fit, errorBuilder: (_, _, _) => const SizedBox.shrink());
  }
  final name = '${key}_$idx';
  if (_bgDir != null && _localBg.contains(name)) {
    return Image.file(File('${_bgDir!.path}/$name.jpg'),
        fit: fit, errorBuilder: (_, _, _) => const SizedBox.shrink());
  }
  // 아직 안 받았으면 원격 스트리밍(캐시) 폴백.
  return CachedNetworkImage(
    imageUrl: '${appConfig.bgRemoteBase}/$name.jpg',
    fit: fit,
    fadeInDuration: const Duration(milliseconds: 200),
    placeholder: (_, _) => const SizedBox.shrink(),
    errorWidget: (_, _, _) => const SizedBox.shrink(),
  );
}

/// 원격 사진의 공유 캡처 전 미리 로드(캐시). 번들 범위면 즉시 반환.
Future<void> precacheBg(BuildContext context, String gradientKey, int idx) async {
  final key = effectiveBgKey(gradientKey);
  if (idx <= (_bundledBgCount[key] ?? 0)) return;
  final name = '${key}_$idx';
  try {
    if (_bgDir != null && _localBg.contains(name)) {
      await precacheImage(FileImage(File('${_bgDir!.path}/$name.jpg')), context);
    } else {
      await precacheImage(
          CachedNetworkImageProvider('${appConfig.bgRemoteBase}/$name.jpg'),
          context);
    }
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
                // 아주 옅은 가독성 스크림(글씨 뒤에만 살짝) — 배경이 밝게 보이게
                DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.85,
                      colors: [Color(0x1F000000), Color(0x00000000)],
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

class _EditShareScreenState extends State<EditShareScreen>
    with SingleTickerProviderStateMixin {
  final _boundaryKey = GlobalKey();
  late final TextEditingController _controller;
  late int _bgIdx;
  late String _bgCategory; // 배경을 고를 분위기 풀(카드 기본값에서 시작, 변경 가능)

  // 배경 분위기(카테고리) 목록 — 시니어용 한글 이름.
  static const _bgCats = [
    ('sunset', '노을'),
    ('sunrise', '해돋이'),
    ('spring', '봄꽃'),
    ('rose', '붉은꽃'),
    ('lavender', '보라꽃'),
    ('calm', '바다·호수'),
    ('night', '밤·달'),
    ('animal', '동물'),
    ('cafe', '카페'),
    ('library', '도서관'),
  ];
  final List<_Sticker> _stickers = [];
  int? _selected;
  bool _sharing = false;
  bool _capturing = false; // 공유 캡처 순간엔 정지된 단일 카드로 렌더

  // 배경 캐러셀: 드래그 오프셋(px)과 카드 간격(px, build에서 갱신).
  late final AnimationController _anim;
  VoidCallback? _animListener;
  double _drag = 0;
  double _step = 1;

  // 문구 위치(정규화 0~1, 카드 기준). 손잡이로 옮긴다. 기본 가운데.
  Offset _textPos = const Offset(0.5, 0.5);
  // 문구 정렬(왼쪽/가운데/오른쪽).
  TextAlign _textAlign = TextAlign.center;
  // 글자 도구(정렬·이동) 펼침 여부. 기본은 접힘 → 글자가 잘 보이게.
  bool _textToolsOpen = false;

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
    _bgCategory = effectiveBgKey(widget.card.gradient); // warm 제거 대응
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 240));
  }

  /// 배경을 한 칸 넘긴다. dir: +1 다음 / -1 이전. (캐러셀 애니메이션 후 확정)
  void _advance(int dir) {
    final n = bgPoolSize(_bgCategory);
    if (n <= 1) {
      _animateDrag(0);
      return;
    }
    final next =
        dir > 0 ? (_bgIdx % n) + 1 : ((_bgIdx - 2) % n + n) % n + 1;
    _animateDrag(dir > 0 ? -_step : _step, commit: next);
  }

  /// 배경 분위기(카테고리) 변경 → 그 풀의 첫 사진부터.
  void _setCategory(String key) {
    if (key == _bgCategory) return;
    _anim.stop();
    setState(() {
      _bgCategory = key;
      _drag = 0;
      _bgIdx = 1;
    });
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (_drag <= -_step * 0.25 || v < -350) {
      _advance(1); // 왼쪽으로 밀었다 → 다음
    } else if (_drag >= _step * 0.25 || v > 350) {
      _advance(-1); // 오른쪽으로 밀었다 → 이전
    } else {
      _animateDrag(0); // 살짝 → 제자리로
    }
  }

  /// _drag 를 target 까지 애니메이션. commit 이 있으면 끝에서 _bgIdx 확정.
  void _animateDrag(double target, {int? commit}) {
    if (_animListener != null) _anim.removeListener(_animListener!);
    _anim.stop();
    _anim.reset();
    final from = _drag;
    _animListener = () => setState(() =>
        _drag = from + (target - from) * Curves.easeOut.transform(_anim.value));
    _anim.addListener(_animListener!);
    _anim.forward().whenComplete(() {
      if (_animListener != null) _anim.removeListener(_animListener!);
      _animListener = null;
      if (!mounted) return;
      setState(() {
        if (commit != null) _bgIdx = commit;
        _drag = 0;
      });
    });
  }

  @override
  void dispose() {
    _anim.dispose();
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
      _drag = 0; // 가운데 정렬
      _capturing = true; // 정지된 단일 카드로 캡처
    });
    // 원격 배경이면 캡처 전에 로드(캐시)해 이미지가 빠지지 않게.
    await precacheBg(context, _bgCategory, _bgIdx);
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
      if (mounted) {
        setState(() {
          _sharing = false;
          _capturing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            // ── 배경 캐러셀: 글씨는 고정, 배경 이미지만 뒤로 흘러감 ──
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth, h = c.maxHeight;
                  final cardW = math.min(w * 0.74, h - 8);
                  _step = cardW * 1.05;
                  final n = bgPoolSize(_bgCategory);
                  // 공유 캡처 순간: 정지된 단일 카드(이미지+글씨) 하나만.
                  if (_capturing) {
                    return Center(
                      child: SizedBox(
                          width: cardW,
                          height: cardW,
                          child: _cardStack(cardW, capture: true)),
                    );
                  }
                  // 드래그는 가운데 오버레이 안의 빈 곳에서 처리(스티커/글씨가 우선).
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 뒤로 흐르는 배경 이미지 필름(가운데 것 포함 모두 이동)
                      for (int k = -2; k <= 2; k++)
                        Positioned(
                          left: w / 2 + k * _step + _drag - cardW / 2,
                          top: 4,
                          width: cardW,
                          height: cardW,
                          child: _imageTile(
                              ((_bgIdx - 1 + k) % n + n) % n + 1,
                              (k * _step + _drag).abs() / _step),
                        ),
                      // 가운데 고정 오버레이(스크림+글씨+스티커) — 움직이지 않음
                      Positioned(
                        left: w / 2 - cardW / 2,
                        top: 4,
                        width: cardW,
                        height: cardW,
                        child: _cardStack(cardW, capture: false),
                      ),
                    ],
                  );
                },
              ),
            ),
            // ── 배경 분위기(카테고리) 선택 ──
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _bgCats.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final (key, label) = _bgCats[i];
                  final sel = key == _bgCategory;
                  return ChoiceChip(
                    label: Text(label,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : Colors.white70)),
                    selected: sel,
                    onSelected: (_) => _setCategory(key),
                    showCheckmark: false,
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                    selectedColor: const Color(0xFF00704A),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  );
                },
              ),
            ),
            // ── 배경 넘기기(화살표) + 위치 표시 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _bgArrow(Icons.chevron_left_rounded, () => _advance(-1)),
                  const SizedBox(width: 18),
                  Text('$_bgIdx / ${bgPoolSize(_bgCategory)}',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 18),
                  _bgArrow(Icons.chevron_right_rounded, () => _advance(1)),
                ],
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

  /// 뒤로 흐르는 배경 이미지 타일(사진만). dist: 가운데서 떨어진 정도(0~1↑) → 멀수록 어둡게.
  Widget _imageTile(int img, double dist) {
    final dim = (dist.clamp(0.0, 1.0)) * 0.35; // 가운데 0 → 가장자리 0.35 어둡게
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
              decoration: BoxDecoration(
                  gradient: cardGradientFor(_bgCategory).gradient)),
          bgImage(_bgCategory, img),
          Container(color: Color.fromRGBO(0, 0, 0, dim)),
        ],
      ),
    );
  }

  /// 카드 오버레이 스택. capture=true면 배경 이미지까지 포함해 캡처 대상(RepaintBoundary),
  /// capture=false면 배경 없이 스크림+글씨만(뒤 필름이 비쳐 보임) — 가운데 고정 레이어.
  Widget _cardStack(double side, {required bool capture}) {
    final children = <Widget>[
      if (capture) ...[
        Positioned.fill(
          child: DecoratedBox(
              decoration: BoxDecoration(
                  gradient: cardGradientFor(_bgCategory).gradient)),
        ),
        Positioned.fill(child: bgImage(_bgCategory, _bgIdx)),
      ],
      // 아주 옅은 가독성 스크림(글씨 뒤에만 살짝) — 배경이 밝게 보이도록 대폭 축소
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
                radius: 0.85,
                colors: [Color(0x1F000000), Color(0x00000000)]),
          ),
        ),
      ),
      // 빈 곳: 탭 → 선택 해제 / 좌우로 밀면 배경만 흐름 (스티커·글씨가 우선)
      if (!capture)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _selected = null),
            onHorizontalDragUpdate: (d) => setState(() =>
                _drag = (_drag + d.delta.dx).clamp(-_step, _step)),
            onHorizontalDragEnd: _onDragEnd,
          ),
        ),
      // 문구 — 위치 이동 가능(손잡이로 옮기고, 글자 탭하면 편집).
      Align(
        alignment: Alignment(_textPos.dx * 2 - 1, _textPos.dy * 2 - 1),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: side * 0.82),
          child: TextField(
            controller: _controller,
            maxLines: null,
            textAlign: _textAlign,
            cursorColor: Colors.white,
            onTap: () => setState(() => _selected = null),
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
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
        ),
      ),
      // 글자 도구(정렬·이동) — 접고 펴기. 접히면 작은 버튼만 → 글자가 잘 보임. 캡처엔 미표시.
      if (!capture)
        Positioned(
          left: 0,
          right: 0,
          top: (_textPos.dy * side - side * 0.145).clamp(0.0, side * 0.88),
          child: Align(
            alignment: Alignment(_textPos.dx * 2 - 1, 0),
            child: _textToolsOpen
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _alignBtn(
                          TextAlign.left, Icons.format_align_left_rounded),
                      const SizedBox(width: 4),
                      _alignBtn(
                          TextAlign.center, Icons.format_align_center_rounded),
                      const SizedBox(width: 4),
                      _alignBtn(
                          TextAlign.right, Icons.format_align_right_rounded),
                      const SizedBox(width: 8),
                      _textMoveHandle(side),
                      const SizedBox(width: 6),
                      _toolToggle(false, Icons.close_rounded),
                    ],
                  )
                : _toolToggle(true, Icons.text_format_rounded),
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
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: side * 0.036,
              fontWeight: FontWeight.w700,
              shadows: _shadow,
            )),
      ),
      for (int i = 0; i < _stickers.length; i++) _stickerWidget(i, side),
    ];
    final stack = Stack(children: children);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: capture
          ? RepaintBoundary(key: _boundaryKey, child: stack)
          : stack,
    );
  }

  /// 글자 도구 접기/펴기 버튼.
  Widget _toolToggle(bool open, IconData icon) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _textToolsOpen = open),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF00704A),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 5)],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  /// 글자 정렬 버튼(왼쪽/가운데/오른쪽). 현재 정렬이면 초록 강조.
  Widget _alignBtn(TextAlign a, IconData icon) {
    final on = _textAlign == a;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _textAlign = a),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? const Color(0xFF00704A) : const Color(0xE6303030),
          borderRadius: BorderRadius.circular(9),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4)],
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  /// 글자 블록을 잡고 옮기는 손잡이(편집 화면 표시용, 공유 캡처엔 안 나옴).
  Widget _textMoveHandle(double side) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (d) => setState(() {
        _textPos = Offset(
          (_textPos.dx + d.delta.dx / side).clamp(0.18, 0.82),
          (_textPos.dy + d.delta.dy / side).clamp(0.14, 0.86),
        );
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF00704A),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 6)],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_with_rounded, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text('글자 이동',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _bgArrow(IconData icon, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      radius: 30,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 32),
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
        behavior: HitTestBehavior.opaque, // 스티커 전체를 잡을 수 있게 + 캐러셀 드래그보다 우선
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
