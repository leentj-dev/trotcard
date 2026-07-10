# Conversation Log - 2026-07-08

## Summary
Android(v36)를 Play Store 비공개 테스트(alpha) 트랙에 자동 업로드 성공. iOS는 이미 TestFlight에 올라가 있음(v1.0.0(35) VALID, 심사 제출 대기). 피드 광고 미노출 원인 규명(신규 AdMob 단위 no-fill) 및 iOS AdMob App ID 설정.

## Issues & Solutions

### Android fastlane 업로드 3연속 실패 → 해결
- **Problem**: `fastlane android closed`가 계속 실패
- **Cause & Solution** (순차 해결):
  1. `Package not found: dev.leentj.kpop_hangul` → 서비스 계정(bible-memorize 프로젝트 키 재사용) 권한 문제. 사용자가 Play Console에서 앱 접근 권한 부여 → 해결
  2. `Version code 35 has already been used` → pubspec 버전 1.0.0+35 → **+36**으로 bump 후 AAB 재빌드
  3. `Track not found: closed` → androidpublisher tracks API로 조회한 결과 실제 트랙은 `internal/alpha/beta/production`뿐. Play Console "비공개 테스트" = **`alpha`** 트랙. Fastfile `track: "closed"` → **`"alpha"`**로 수정
- **결과**: v36이 alpha 트랙에 `status=draft`로 업로드됨. **테스터가 받으려면 Play Console에서 "출시 검토 → 출시 시작" 필요**
- **Files**: `app/pubspec.yaml`, `app/android/fastlane/Fastfile`

### iOS 출시 상태 확인
- **방법**: App Store Connect API(AuthKey_DPCWVWG2NC.p8)로 JWT 생성 → 직접 조회
- **결과**: TestFlight 빌드 `v1.0.0 (35)` state=**VALID**, App Store 버전 `1.0.0` state=**READY_FOR_REVIEW** (심사 제출 버튼만 누르면 됨)

### 피드 리스트에 광고 안 나옴
- **Problem**: "아까 광고 나왔는데 지금 안 나온다"
- **Cause**: Remote Config에서 2시간 전 `native_ad_unit_android/ios`를 구글 테스트 ID(빈값) → **실제 AdMob 단위**로 교체. 신규 AdMob 광고 단위는 몇 시간~하루 no-fill이 정상. 이전엔 테스트 광고라 떴던 것
- **확인된 정상 셋업**: ads_enabled=true, App ID와 광고단위가 모두 동일 퍼블리셔(`6232115093331648`). 코드(MobileAds 초기화·Android songCard 팩토리·피드 삽입)도 정상
- **대응**: 기다리거나, Remote Config 값을 잠깐 비워 테스트 광고로 통합 검증

### iOS AdMob App ID 미설정
- **Problem**: AdMob App ID는 플랫폼별 2개 필요(안드/애플). iOS Info.plist에 `GADApplicationIdentifier` 없음
- **Solution**: iOS App ID `ca-app-pub-6232115093331648~1473131249`를 Info.plist에 추가
  - 안드: `ca-app-pub-6232115093331648~5603947943` (기존)
- **Files**: `app/ios/Runner/Info.plist`

## Decisions Made
- Play Console "비공개 테스트" ↔ fastlane `alpha` 트랙 매핑 확정 (Fastfile 주석으로 기록)
- Android/iOS 광고 셋업은 정상 — 광고 미노출은 신규 단위 no-fill이며 코드 문제 아님
- iOS 릴리스는 이미 완료 상태(심사 제출만 남음)

## TODO / Follow-up
- [ ] **Android**: Play Console에서 v36 draft를 "출시 시작"해야 테스터 설치 가능
- [ ] **iOS 네이티브 광고 미구현**: `songCard` NativeAdFactory가 iOS(AppDelegate.swift)에 등록 안 됨 + Swift 팩토리 클래스 없음 → App ID 넣어도 iOS 네이티브광고는 렌더 안 됨. 구현 필요
- [ ] **AdMob no-fill**: 실제 광고 서빙까지 대기(계정/앱 승인·연결 확인). 급하면 테스트 광고로 검증
- [ ] **iOS 심사 제출**: App Store Connect에서 "심사 제출" 버튼
- [ ] 다음 자동배포 시 즉시 롤아웃하려면 Fastfile `release_status: "draft"` → `"completed"` 고려
