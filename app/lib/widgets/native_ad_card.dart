import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/remote_config.dart';
import '../config/theme_controller.dart';
import '../utils/ads.dart';

/// A native AdMob ad rendered by the platform "songCard" factory, styled to
/// look like a song list row (thumbnail + title + artist). Auto-refreshes on
/// a Remote-Config-driven interval and hides entirely when ads are disabled.
/// Used both in the song feed and under the word deck so it reads like
/// content, not a banner.
class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key});

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _ad;
  bool _loaded = false;
  Timer? _refreshTimer;

  // 광고 아이콘은 작은 로고라 행만큼 키우면 깨진다 → 컴팩트한 높이.
  static const _height = 92.0;

  @override
  void initState() {
    super.initState();
    _loadAd();
    _startRefreshTimer();
    nativeAdRefreshSecNotifier.addListener(_startRefreshTimer);
    // 라이트/다크 전환 시 글자색이 따라오도록 광고를 다시 로드한다.
    themeModeNotifier.addListener(_loadAd);
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(seconds: nativeAdRefreshSecNotifier.value),
      (_) => _loadAd(),
    );
  }

  void _loadAd() {
    NativeAd(
      adUnitId: Ads.feedNativeUnitId,
      factoryId: 'songCard',
      request: const AdRequest(),
      // 네이티브 팩토리가 리스트 행 글자색에 맞추도록 현재 테마를 전달.
      customOptions: {
        'dark': themeModeNotifier.value == ThemeMode.dark,
      },
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          final old = _ad;
          setState(() {
            _ad = ad as NativeAd;
            _loaded = true;
          });
          old?.dispose();
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    ).load();
  }

  @override
  void dispose() {
    nativeAdRefreshSecNotifier.removeListener(_startRefreshTimer);
    themeModeNotifier.removeListener(_loadAd);
    _refreshTimer?.cancel();
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
        // The native layout (native_ad_song.xml) draws its own rounded
        // background/border, so this just reserves height.
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          height: _height,
          child: AdWidget(ad: _ad!),
        );
      },
    );
  }
}
