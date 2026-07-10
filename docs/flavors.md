# Multi-flavor architecture (shared engine, per-language content)

The app is a reusable engine — feed, YouTube-synced word cards, TTS, ads,
GitHub-raw remote updates — with the language-specific bits isolated in
`lib/config/`. Each "flavor" is a separate store app that shares 100% of the
engine and swaps only branding, content source, and the learned-language
word logic.

## What differs per flavor (`lib/config/app_config.dart`)
- `appTitle`, `logoAsset`, `seedColor` — branding
- `remoteBase` — GitHub-raw base for that app's song manifest/files
- `target` (`TargetLanguage`) — TTS locale + per-word breakdown chips

## TargetLanguage strategies (`lib/config/target_language.dart`)
- `KoreanTarget` — jamo decomposition (ㅂ + ㅗ + ㄴ), ko-KR
- `JapaneseTarget` — ja-JP, no auto breakdown yet (furigana would come from data)
- `RomanTarget(locale)` — Spanish etc.; no breakdown (already romanized)

## Entrypoints
- `lib/main.dart` → K-pop Hangul (Korean) — the live app
- `lib/main_jpop.dart` → J-pop (Japanese)  ·  `flutter run -t lib/main_jpop.dart`
- `lib/main_es.dart` → Latin (Spanish)     ·  `flutter run -t lib/main_es.dart`

All call `bootstrap(config)` in `lib/app.dart`.

## Song JSON is shared
The headword stays in `WordEntry.korean` for every flavor (just the target
surface form); `example`/`translation` fields are unchanged. So the same
`scripts/sync_timestamps.py` + `consolidate_songs.py` pipeline and the 7-language
learner translations work as-is.

## To ship a new flavor (store)
1. Point its `remoteBase` at that language's song pack (new repo path/folder).
2. Add real branding (name, icon, colors).
3. Set up its own Android/iOS flavor (applicationId/bundleId) + AdMob + Firebase.
4. Build with `-t lib/main_<flavor>.dart`.

Currently jpop/es configs reuse the kpop content path as placeholders — they
need their own song packs before release.
