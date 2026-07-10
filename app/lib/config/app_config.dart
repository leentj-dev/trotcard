import 'dart:io';

import 'package:flutter/material.dart';

import 'target_language.dart';

/// Per-flavor configuration. The engine (feed, player, word cards, ads,
/// remote updates) is shared; only these values change between apps.
class AppConfig {
  final String appTitle;
  final String logoAsset;
  final Color seedColor;

  /// Bundled asset dir for this flavor's songs, e.g. 'assets/songs'.
  final String assetDir;

  /// Base URL for the song manifest + files (GitHub raw, no backend).
  final String remoteBase;

  /// The language being learned.
  final TargetLanguage target;

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
    required this.target,
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

/// 트롯 퀴즈 — 시니어용 트롯트 두뇌 게임 (단일 앱).
const trotConfig = AppConfig(
  appTitle: '트롯 퀴즈',
  logoAsset: 'assets/icon/icon.png',
  seedColor: Color(0xFFE11D48), // 트롯 레드
  assetDir: 'assets/songs',
  remoteBase:
      'https://raw.githubusercontent.com/leentj-dev/trot/main/app/assets/songs',
  target: KoreanTarget(),
  androidPackageId: 'dev.leentj.trot_quiz',
  iosAppId: '', // App Store 등록 후 채움
);
