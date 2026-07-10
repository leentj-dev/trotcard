import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/song.dart';
import '../utils/card_gradients.dart';

/// 분위기 키별 배경 사진 풀 개수 (`assets/bg/{key}_1..N.jpg`).
const _bgPoolCount = {
  'warm': 14, 'sunrise': 14, 'spring': 14, 'calm': 14,
  'sunset': 14, 'night': 14, 'rose': 14, 'lavender': 14,
};

/// 문자열 안정 해시 (Dart String.hashCode는 런마다 달라질 수 있어 직접 계산).
int _stableHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

/// 카드마다 분위기 풀에서 고정된 사진 하나를 고른다(같은 카드=항상 같은 사진).
String bgAssetFor(GreetingCard card) {
  final key = card.gradient;
  final n = _bgPoolCount[key] ?? 1;
  final idx = _stableHash(card.text) % n + 1;
  return 'assets/bg/${key}_$idx.jpg';
}

/// 마음 카드의 순수 비주얼. 그리드 타일·전체보기·공유 캡처에 공통으로 쓴다.
/// 정사각형(1:1) — 카톡 공유 이미지에 잘 맞는 비율.
class GreetingCardView extends StatelessWidget {
  final GreetingCard card;

  /// 하단 브랜드 워터마크 표시 여부 (공유 이미지엔 표시, 필요 시 숨김).
  final bool showBrand;

  /// 배경 사진 경로 고정용(문구 편집 미리보기에서 사진이 안 바뀌게). null이면
  /// 카드 텍스트 해시로 자동 선택.
  final String? bgAsset;

  const GreetingCardView({
    super.key,
    required this.card,
    this.showBrand = true,
    this.bgAsset,
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
                Image.asset(
                  bgAsset ?? bgAssetFor(card),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
                // 가독성 스크림: 전체 은은하게 + 가운데 진하게
                Container(color: const Color(0x33000000)),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.9,
                      colors: [Color(0x88000000), Color(0x11000000)],
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

/// 문구를 수정한 뒤 이미지로 공유하는 화면.
/// 카드를 크게 미리보기하고, 아래 입력칸에서 문구를 고쳐 바로 보낼 수 있다.
/// 배경 사진은 원래 카드 기준으로 고정(편집 중 사진이 바뀌지 않음).
class EditShareScreen extends StatefulWidget {
  final GreetingCard card;

  const EditShareScreen({super.key, required this.card});

  @override
  State<EditShareScreen> createState() => _EditShareScreenState();
}

class _EditShareScreenState extends State<EditShareScreen> {
  final _boundaryKey = GlobalKey();
  late final TextEditingController _controller;
  late final String _bgAsset;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.card.text);
    _bgAsset = bgAssetFor(widget.card); // 원래 카드 기준 사진 고정
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
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
    final preview = widget.card.copyWith(text: _controller.text);
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // 미리보기 (편집 문구 실시간 반영, 사진 고정)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: GreetingCardView(
                          card: preview,
                          bgAsset: _bgAsset,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 문구 입력칸 (시니어용 큰 글씨)
                    TextField(
                      controller: _controller,
                      maxLines: 3,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          height: 1.4),
                      decoration: InputDecoration(
                        hintText: '문구를 입력하세요',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('문구를 자유롭게 고칠 수 있어요',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 13)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 62,
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
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Icon(Icons.ios_share_rounded, size: 26),
                  label: const Text('이미지로 보내기',
                      style: TextStyle(
                          fontSize: 21, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
