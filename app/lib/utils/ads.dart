import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/remote_config.dart';

/// AdMob 광고 단위 설정.
///
/// 실제 AdMob 광고 단위 ID(3개 슬롯 × 안드로이드/iOS)를 기본값으로 사용하고,
/// 필요 시 Remote Config 로 재빌드 없이 교체할 수 있다.
/// AdMob App ID 는 AndroidManifest / Info.plist 에 있고 교체 시 재빌드가 필요하다.
class Ads {
  Ads._();

  // ── 실제 광고 단위 ID ─────────────────────────────────────
  // 피드(리스트) 네이티브
  static const _feedNativeAndroid = 'ca-app-pub-6232115093331648/1833962005';
  static const _feedNativeIos = 'ca-app-pub-6232115093331648/2523237462';
  // 카드 사이 네이티브
  static const _cardNativeAndroid = 'ca-app-pub-6232115093331648/9280217502';
  static const _cardNativeIos = 'ca-app-pub-6232115093331648/6270910783';
  // 카드 아래 배너
  static const _bannerAndroid = 'ca-app-pub-6232115093331648/2710140961';
  static const _bannerIos = 'ca-app-pub-6232115093331648/3644747446';

  /// 피드에서 곡 N개마다 광고 삽입 (Remote Config feed_ad_interval 로 조절).
  static const feedInterval = 8;

  /// 피드(리스트) 네이티브 광고 단위 — Remote Config 오버라이드 우선.
  static String get feedNativeUnitId =>
      nativeAdUnitOverride() ??
      (Platform.isIOS ? _feedNativeIos : _feedNativeAndroid);

  /// 카드 사이 네이티브 광고 단위 — Remote Config 오버라이드 우선.
  static String get cardNativeUnitId =>
      cardNativeAdUnitOverride() ??
      (Platform.isIOS ? _cardNativeIos : _cardNativeAndroid);

  /// 카드 아래 배너 광고 단위 — Remote Config 오버라이드 우선.
  static String get bannerUnitId =>
      bannerAdUnitOverride() ??
      (Platform.isIOS ? _bannerIos : _bannerAndroid);
}
