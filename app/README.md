# 트로트카드 (trotcard)

트롯을 들으며 "마음 카드"를 나누는 **시니어(노년층) 대상** Flutter 앱.
유튜브로 트롯을 들으면서 곡 분위기에 맞는 안부 카드를 골라 **이미지(PNG)로 공유**한다.

자세한 컨셉·구조·규칙은 저장소 루트의 [`CLAUDE.md`](../CLAUDE.md) 참고.

## 개발

```bash
flutter pub get
flutter run              # 디버그 실행
flutter analyze          # 정적 분석
```

## 곡·카드 추가 (OTA)

곡과 마음 카드는 `assets/songs/<id>.json`에 있고, 수정 후 매니페스트만 재생성해
push 하면 앱이 자동 동기화한다(재빌드 불필요).

```bash
python3 scripts/build_manifest_cards.py   # manifest.json 재생성
```

## 배포

- Android: `flutter build apk --release` → Firebase App Distribution / Play
- iOS: `ios/fastlane` — `fastlane beta`(빌드+TestFlight) 또는 `fastlane ship`
