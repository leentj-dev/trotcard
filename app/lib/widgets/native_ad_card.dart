import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/remote_config.dart';
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

  static const _height = 92.0;

  @override
  void initState() {
    super.initState();
    _loadAd();
    _startRefreshTimer();
    nativeAdRefreshSecNotifier.addListener(_startRefreshTimer);
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
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          height: _height,
          child: AdWidget(ad: _ad!),
        );
      },
    );
  }
}
