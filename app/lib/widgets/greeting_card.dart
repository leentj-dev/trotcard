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
      child: LayoutBuilder(
        builder: (context, c) {
          final s = c.maxWidth; // 정사각형 한 변
          return Container(
            decoration: BoxDecoration(gradient: g.gradient),
            child: Stack(
              children: [
                // 하단 꽃 정원 장식
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Image.asset(
                    'assets/deco/floral.png',
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
                // 문구 (윗쪽~가운데, 꽃 밴드 위 공간 확보)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      s * 0.09, s * 0.10, s * 0.09, s * 0.33),
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
                              style: TextStyle(
                                color: g.foreground,
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                                height: 1.4,
                              ),
                            ),
                            if (showBrand) ...[
                              const SizedBox(height: 20),
                              Text(
                                '💌 트로트 카드',
                                style: TextStyle(
                                  color: g.foreground.withValues(alpha: 0.6),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
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
      '${dir.path}/trot_card_${DateTime.now().millisecondsSinceEpoch}.png');
  await file.writeAsBytes(bytes.buffer.asUint8List());

  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: text),
  );
}
