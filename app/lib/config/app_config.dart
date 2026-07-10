import 'dart:io';

import 'package:flutter/material.dart';

/// 앱 설정. 엔진(피드, 플레이어, 마음 카드, 광고, 원격 업데이트)은 공유하고
/// 이 값들만 앱마다 바뀐다.
class AppConfig {
  final String appTitle;
  final String logoAsset;
  final Color seedColor;

  /// 번들 노래 자산 디렉토리, 예: 'assets/songs'.
  final String assetDir;

  /// 노래 manifest + 파일의 base URL (GitHub raw, 백엔드 불필요).
  final String remoteBase;

  /// Android application id (for the Play Store update link).
  final String androidPackageId;

  /// App Store numeric app id (for the App Store update link).
  final String iosAppId;

  const AppConfig({
    required this.appTitle,
    required this.logoAsset,
    required this.seedColor,
    required this.assetDir,
    required this.remoteBase,
    required this.androidPackageId,
    this.iosAppId = '',
  });

  /// Local cache subdir name, derived from [assetDir] (e.g. 'songs_jpop').
  String get localDirName => assetDir.split('/').last;

  /// Store page URL for the current platform (used by the force-update prompt).
  String get storeUrl => Platform.isIOS
      ? 'https://apps.apple.com/app/id$iosAppId'
      : 'https://play.google.com/store/apps/details?id=$androidPackageId';
}

/// Set once by the flavor entrypoint (main*.dart) before runApp().
late AppConfig appConfig;

/// 트로트 카드 — 트롯을 들으며 마음 카드를 나누는 시니어용 앱 (단일 앱).
const trotConfig = AppConfig(
  appTitle: '트로트 카드',
  logoAsset: 'assets/icon/icon.png',
  seedColor: Color(0xFFE11D48), // 트롯 레드
  assetDir: 'assets/songs',
  remoteBase:
      'https://raw.githubusercontent.com/leentj-dev/trotcard/main/app/assets/songs',
  androidPackageId: 'dev.leentj.trotcard',
  iosAppId: '', // App Store 등록 후 채움
);
