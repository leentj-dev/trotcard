import 'dart:io';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Whether ads should be shown. Driven by the Firebase Remote Config key
/// `ads_enabled`; defaults to true so ads still show if Remote Config is
/// unreachable. UI widgets listen to this and hide ad slots when it's false.
final adsEnabledNotifier = ValueNotifier<bool>(true);

/// How many songs appear between feed ads. Driven by `feed_ad_interval`.
final feedAdIntervalNotifier = ValueNotifier<int>(8);

/// How many cards appear between native ads in the song detail pager.
/// Driven by `card_ad_interval`. Default 5.
final cardAdIntervalNotifier = ValueNotifier<int>(5);

/// Seconds between native-ad auto-refreshes. Driven by `native_ad_refresh_sec`.
final nativeAdRefreshSecNotifier = ValueNotifier<int>(60);

/// Seconds between banner-ad auto-refreshes. Driven by `banner_ad_refresh_sec`.
final bannerAdRefreshSecNotifier = ValueNotifier<int>(60);

/// Minimum required build number (pubspec `+NN`). Driven by `min_version`.
/// If the running build is below this, a blocking update prompt is shown.
/// 0 = no forced update.
final minVersionNotifier = ValueNotifier<int>(0);

/// 카드가 자동으로 다음 장으로 넘어가는 간격(초). Driven by `card_auto_sec`. 기본 4.
final cardAutoSecNotifier = ValueNotifier<int>(4);

/// 손으로 넘긴 뒤 자동넘김이 다시 켜지기까지 대기(초). Driven by
/// `card_resume_sec`. 기본 10.
final cardResumeSecNotifier = ValueNotifier<int>(10);

const _adsEnabledKey = 'ads_enabled';
const _feedAdIntervalKey = 'feed_ad_interval';
const _cardAdIntervalKey = 'card_ad_interval';
const _nativeRefreshKey = 'native_ad_refresh_sec';
const _bannerRefreshKey = 'banner_ad_refresh_sec';
const _minVersionKey = 'min_version';
const _cardAutoSecKey = 'card_auto_sec';
const _cardResumeSecKey = 'card_resume_sec';
const _nativeUnitAndroidKey = 'native_ad_unit_android'; // 피드(리스트) 네이티브
const _nativeUnitIosKey = 'native_ad_unit_ios';
const _cardNativeUnitAndroidKey = 'card_native_ad_unit_android'; // 카드 사이 네이티브
const _cardNativeUnitIosKey = 'card_native_ad_unit_ios';
const _bannerUnitAndroidKey = 'banner_ad_unit_android';
const _bannerUnitIosKey = 'banner_ad_unit_ios';

// Remote-overridable ad unit IDs (empty = use the built-in default in ads.dart).
// NOTE: only the ad *unit* IDs are remote-configurable. The AdMob *App ID*
// is read from AndroidManifest/Info.plist at startup and needs a rebuild.
String _nativeUnitAndroid = '';
String _nativeUnitIos = '';
String _cardNativeUnitAndroid = '';
String _cardNativeUnitIos = '';
String _bannerUnitAndroid = '';
String _bannerUnitIos = '';

/// 피드(리스트) 네이티브 광고 단위 원격 오버라이드, 없으면 null.
String? nativeAdUnitOverride() {
  final v = Platform.isIOS ? _nativeUnitIos : _nativeUnitAndroid;
  return v.isEmpty ? null : v;
}

/// 카드 사이 네이티브 광고 단위 원격 오버라이드, 없으면 null.
String? cardNativeAdUnitOverride() {
  final v = Platform.isIOS ? _cardNativeUnitIos : _cardNativeUnitAndroid;
  return v.isEmpty ? null : v;
}

/// 배너 광고 단위 원격 오버라이드, 없으면 null.
String? bannerAdUnitOverride() {
  final v = Platform.isIOS ? _bannerUnitIos : _bannerUnitAndroid;
  return v.isEmpty ? null : v;
}

/// Fetch + activate Remote Config, then publish the ad flag. Never throws —
/// on any failure the app keeps the current (default) value.
Future<void> initRemoteConfig() async {
  try {
    final rc = FirebaseRemoteConfig.instance;
    await rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      // No throttle: every cold start fetches the latest config immediately.
      // (Live updates while the app is open already arrive via onConfigUpdated.)
      minimumFetchInterval: Duration.zero,
    ));
    await rc.setDefaults(const {
      _adsEnabledKey: true,
      _feedAdIntervalKey: 8,
      _cardAdIntervalKey: 5,
      _nativeRefreshKey: 60,
      _bannerRefreshKey: 60,
      _nativeUnitAndroidKey: '',
      _nativeUnitIosKey: '',
      _cardNativeUnitAndroidKey: '',
      _cardNativeUnitIosKey: '',
      _bannerUnitAndroidKey: '',
      _bannerUnitIosKey: '',
      _minVersionKey: 0,
      _cardAutoSecKey: 4,
      _cardResumeSecKey: 10,
    });
    await rc.fetchAndActivate();
    _publish(rc);

    // Pick up changes pushed while the app is open.
    rc.onConfigUpdated.listen((event) async {
      await rc.activate();
      _publish(rc);
    });
  } on Exception {
    // Keep the defaults.
  }
}

void _publish(FirebaseRemoteConfig rc) {
  adsEnabledNotifier.value = rc.getBool(_adsEnabledKey);
  final interval = rc.getInt(_feedAdIntervalKey);
  // Guard against a bad/zero value making every row an ad.
  feedAdIntervalNotifier.value = interval >= 2 ? interval : 8;
  final cardInterval = rc.getInt(_cardAdIntervalKey);
  cardAdIntervalNotifier.value = cardInterval >= 2 ? cardInterval : 5;
  // AdMob requires >= 30s; clamp to a safe floor.
  final refresh = rc.getInt(_nativeRefreshKey);
  nativeAdRefreshSecNotifier.value = refresh >= 30 ? refresh : 60;
  final bannerRefresh = rc.getInt(_bannerRefreshKey);
  bannerAdRefreshSecNotifier.value = bannerRefresh >= 30 ? bannerRefresh : 60;
  _nativeUnitAndroid = rc.getString(_nativeUnitAndroidKey);
  _nativeUnitIos = rc.getString(_nativeUnitIosKey);
  _cardNativeUnitAndroid = rc.getString(_cardNativeUnitAndroidKey);
  _cardNativeUnitIos = rc.getString(_cardNativeUnitIosKey);
  _bannerUnitAndroid = rc.getString(_bannerUnitAndroidKey);
  _bannerUnitIos = rc.getString(_bannerUnitIosKey);
  minVersionNotifier.value = rc.getInt(_minVersionKey);
  // 카드 넘김 속도: 비정상 값 방어(자동 2~30초, 재개 3~120초).
  final auto = rc.getInt(_cardAutoSecKey);
  cardAutoSecNotifier.value = (auto >= 2 && auto <= 30) ? auto : 4;
  final resume = rc.getInt(_cardResumeSecKey);
  cardResumeSecNotifier.value = (resume >= 3 && resume <= 120) ? resume : 10;
}
