import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'config/app_config.dart';
import 'config/remote_config.dart';
import 'config/theme_controller.dart';
import 'screens/feed_screen.dart';
import 'widgets/greeting_card.dart';

/// Shared entrypoint used by every flavor. Set [appConfig] first, then call.
Future<void> bootstrap(AppConfig config) async {
  appConfig = config;
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  loadThemeMode();
  await loadBgCounts(); // 원격 배경 사진 장수(OTA) 적용

  try {
    await Firebase.initializeApp();
    await initRemoteConfig();
  } on Exception {
    // App runs fine without Firebase; ads stay at their default (on).
  }
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  ThemeData _theme(Brightness brightness) => ThemeData(
        brightness: brightness,
        scaffoldBackgroundColor:
            brightness == Brightness.dark ? Colors.black : Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: appConfig.seedColor,
          brightness: brightness,
        ),
        useMaterial3: true,
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) => MaterialApp(
        title: appConfig.appTitle,
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        home: const FeedScreen(),
      ),
    );
  }
}
