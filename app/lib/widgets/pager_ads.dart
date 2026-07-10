import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/remote_config.dart';
import '../utils/ads.dart';

/// 카드 사이에 들어가는 "예쁜" 네이티브 광고. google_mobile_ads 의 medium
/// 네이티브 템플릿을 앱 톤(어두운 카드 + 그린 CTA)으로 커스텀해 카드처럼 보이게 한다.
class CardNativeAd extends StatefulWidget {
  const CardNativeAd({super.key});

  @override
  State<CardNativeAd> createState() => _CardNativeAdState();
}

class _CardNativeAdState extends State<CardNativeAd> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _ad = NativeAd(
      adUnitId: Ads.nativeUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: const Color(0xFF241019),
        cornerRadius: 20,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFF00704A),
          style: NativeTemplateFontStyle.bold,
          size: 16,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          style: NativeTemplateFontStyle.bold,
          size: 18,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white.withValues(alpha: 0.75),
          size: 14,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white.withValues(alpha: 0.55),
          size: 12,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _ad = ad as NativeAd;
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: adsEnabledNotifier,
      builder: (context, enabled, _) {
        if (!enabled) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('광고',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    width: 330,
                    height: 340,
                    child: (_loaded && _ad != null)
                        ? AdWidget(ad: _ad!)
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white38),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 카드 아래 고정 배너 광고. 광고가 꺼져 있거나 로드 전이면 자리를 차지하지 않는다.
class BannerAdBar extends StatefulWidget {
  const BannerAdBar({super.key});

  @override
  State<BannerAdBar> createState() => _BannerAdBarState();
}

class _BannerAdBarState extends State<BannerAdBar> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      adUnitId: Ads.bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: adsEnabledNotifier,
      builder: (context, enabled, _) {
        if (!enabled || !_loaded || _ad == null) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          width: _ad!.size.width.toDouble(),
          height: _ad!.size.height.toDouble(),
          child: AdWidget(ad: _ad!),
        );
      },
    );
  }
}
