import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_config.dart';

/// Shows a blocking "update required" dialog when the running build number is
/// below [minVersion] (the Remote Config `min_version`). The dialog can't be
/// dismissed — the only action opens the store page. No-op when [minVersion]
/// is 0 or the current build is up to date.
Future<void> maybeForceUpdate(BuildContext context, int minVersion) async {
  if (minVersion <= 0) return;
  final info = await PackageInfo.fromPlatform();
  final current = int.tryParse(info.buildNumber) ?? 0;
  if (current >= minVersion || !context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('업데이트가 필요해요'),
        content: const Text(
          '새로운 버전이 나왔어요. 계속하려면 최신 버전으로 업데이트해 주세요.\n'
          'A new version is available — please update to continue.',
        ),
        actions: [
          FilledButton(
            onPressed: () => launchUrl(
              Uri.parse(appConfig.storeUrl),
              mode: LaunchMode.externalApplication,
            ),
            child: const Text('업데이트 / Update'),
          ),
        ],
      ),
    ),
  );
}
