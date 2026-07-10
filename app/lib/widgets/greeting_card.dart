import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/song.dart';
import '../utils/card_gradients.dart';

/// 마음 카드의 순수 비주얼. 그리드 타일·전체보기·공유 캡처에 공통으로 쓴다.
/// 정사각형(1:1) — 카톡 공유 이미지에 잘 맞는 비율.
class GreetingCardView extends StatelessWidget {
  final GreetingCard card;

  /// 하단 브랜드 워터마크 표시 여부 (공유 이미지엔 표시, 필요 시 숨김).
  final bool showBrand;

  const GreetingCardView({
    super.key,
    required this.card,
    this.showBrand = true,
  });

  @override
  Widget build(BuildContext context) {
    final g = cardGradientFor(card.gradient);
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(gradient: g.gradient),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Center(
            // 타일(작은 박스)에선 자동 축소, 전체보기에선 자연 크기.
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
                    if (card.emoji.isNotEmpty) const SizedBox(height: 16),
                    Text(
                      card.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: g.foreground,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                    if (showBrand) ...[
                      const SizedBox(height: 22),
                      Text(
                        '💌 트로트 카드',
                        style: TextStyle(
                          color: g.foreground.withValues(alpha: 0.55),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
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
      '${dir.path}/trot_card_${DateTime.now().millisecondsSinceEpoch}.png');
  await file.writeAsBytes(bytes.buffer.asUint8List());

  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: text),
  );
}
