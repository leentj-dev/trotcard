import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/remote_config.dart';
import '../utils/ads.dart';

/// 카드 사이에 들어가는 "예쁜" 네이티브 광고를 **PageView 밖에서** 로드/보관한다.
/// 로드된 광고만 페이저 슬롯으로 노출하기 위함(로드 전/실패 시엔 슬롯 자체를
/// 안 만들어 빈 페이지가 생기지 않게). google_mobile_ads medium 템플릿을 앱 톤
/// (어두운 카드 + 그린 CTA)으로 커스텀. Remote Config `native_ad_refresh_sec`
/// 간격으로 자동 새로고침, 실패 시 지수 백오프 재시도.
class CardNativeAdLoader extends ChangeNotifier {
  NativeAd? _ad;
  bool _disposed = false;
  Timer? _timer;
  Timer? _retry;
  int _retryCount = 0;

  /// 준비된 광고(없으면 null → 슬롯을 만들지 않는다).
  NativeAd? get ad => _ad;

  CardNativeAdLoader() {
    _load();
    _startTimer();
    nativeAdRefreshSecNotifier.addListener(_startTimer);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: nativeAdRefreshSecNotifier.value),
      (_) => _load(),
    );
  }

  void _load() {
    // 새 광고가 로드되면 그때 교체(로드 전까진 기존 광고 유지).
    NativeAd(
      adUnitId: Ads.cardNativeUnitId,
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
          if (_disposed) {
            ad.dispose();
            return;
          }
          _retryCount = 0;
          final old = _ad;
          _ad = ad as NativeAd;
          old?.dispose();
          notifyListeners();
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          debugPrint('[NativeAd] load failed: code=${err.code} '
              '${err.message} (unit=${Ads.cardNativeUnitId})');
          // no-fill 등 일시적 실패 → 지수 백오프로 재시도(최대 ~2분 간격).
          if (_disposed) return;
          final delay = Duration(seconds: (5 << _retryCount).clamp(5, 120));
          if (_retryCount < 5) _retryCount++;
          _retry?.cancel();
          _retry = Timer(delay, () {
            if (!_disposed) _load();
          });
        },
      ),
    ).load();
  }

  @override
  void dispose() {
    _disposed = true;
    nativeAdRefreshSecNotifier.removeListener(_startTimer);
    _timer?.cancel();
    _retry?.cancel();
    _ad?.dispose();
    super.dispose();
  }
}

/// 로드된 네이티브 광고 한 개를 카드처럼 보여준다(페이저 한 슬롯).
class CardNativeAdView extends StatelessWidget {
  final NativeAd ad;

  const CardNativeAdView({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
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
                child: AdWidget(ad: ad),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드 아래 고정 배너 광고. Remote Config `banner_ad_refresh_sec` 간격으로
/// 자동 새로고침. 광고가 꺼져 있거나 로드 전이면 자리를 차지하지 않는다.
class BannerAdBar extends StatefulWidget {
  const BannerAdBar({super.key});

  @override
  State<BannerAdBar> createState() => _BannerAdBarState();
}

class _BannerAdBarState extends State<BannerAdBar> {
  BannerAd? _ad;
  bool _loaded = false;
  Timer? _timer;
  Timer? _retry;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _startTimer();
    bannerAdRefreshSecNotifier.addListener(_startTimer);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: bannerAdRefreshSecNotifier.value),
      (_) => _load(),
    );
  }

  void _load() {
    BannerAd(
      adUnitId: Ads.bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          _retryCount = 0;
          final old = _ad;
          setState(() {
            _ad = ad as BannerAd;
            _loaded = true;
          });
          old?.dispose();
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          debugPrint('[BannerAd] load failed: code=${err.code} '
              '${err.message} (unit=${Ads.bannerUnitId})');
          // no-fill 등 일시적 실패 → 지수 백오프로 재시도(최대 ~2분 간격).
          if (!mounted) return;
          final delay = Duration(seconds: (5 << _retryCount).clamp(5, 120));
          if (_retryCount < 5) _retryCount++;
          _retry?.cancel();
          _retry = Timer(delay, () {
            if (mounted) _load();
          });
        },
      ),
    ).load();
  }

  @override
  void dispose() {
    bannerAdRefreshSecNotifier.removeListener(_startTimer);
    _timer?.cancel();
    _retry?.cancel();
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
