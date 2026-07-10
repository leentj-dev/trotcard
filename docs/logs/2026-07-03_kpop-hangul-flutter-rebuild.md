# Conversation Log - 2026-07-02 ~ 07-03

## Summary
kpop-hangul(외국인 대상 K-pop 단어로 한글 배우기)을 Next.js 웹에서 **Flutter 앱으로 재설계**하고, 백엔드 없이 곡 데이터를 GitHub raw로 원격 업데이트하는 구조로 만들었다. Firebase App Distribution으로 v1.0.0(1)~(14)까지 반복 배포했고, 곡을 56 → **103곡**으로 확장, 광고·자동재생·UI 개선까지 마쳤다.

## Issues & Solutions

### 유튜브 재생 에러 (152-4)
- **Problem**: 앱 내 임베드 플레이어에서 "This video is unavailable. Error code: 152-4"
- **Cause**: youtube_player_iframe 5.2.2의 임베드 origin 검증 이슈
- **Solution**: 6.0.2로 업그레이드
- **Files**: app/pubspec.yaml

### Supabase 삭제됨
- **Problem**: 기존 웹의 Supabase(kh 스키마)가 NXDOMAIN
- **Solution**: 백엔드 제거. 곡 JSON을 앱 에셋 번들 + GitHub raw 원격 업데이트로 전환
- **Files**: app/lib/data/song_repository.dart, scripts/consolidate_songs.py

### 신곡 타임스탬프 없음
- **Problem**: 신곡이 싱크(SYNC) 없이 추가됨
- **Cause**: 실제 곡을 못 들어서 타임스탬프를 못 찍음
- **Solution**: lrclib.net 공개 싱크 가사에서 타이밍만 추출(가사 텍스트 미저장). 단어는 실제 가사 표면형으로 선정해야 매칭됨. scripts/sync_timestamps.py, scripts/batch_sync.py
- **정책 확정**: lrclib에 싱크 가사 있는 곡만 추가

### 100곡 배치 추가
- **Problem**: 오래 업데이트 안 해서 대량 추가 필요
- **Solution**: 7개 장르 버킷 병렬 에이전트로 47곡 생성 → batch_sync로 타임스탬프 → 싱크 미달 3곡 제외 → 44곡 확정(총 103곡, 싱크 76)

### 전체화면 크래시 → 결국 제거
- **Problem**: 전체화면 가로전환 시 크래시, 이후엔 전체화면은 되나 회전 안 됨
- **Cause**: iframe 6.x는 전체화면을 내부(OverlayPortal) 처리. 수동 YoutubePlayerScaffold+SystemChrome 트리 스왑이 웹뷰 재생성 유발
- **최종 결정**: "영상이 아니라 단어 학습이 주"라서 **전체화면 버튼 자체를 제거**(v1.0.0+14)

## Decisions Made
- 백엔드 없음: 곡은 GitHub raw(main `app/assets/songs/`)에서 자동 다운로드. push = 배포.
- 신곡 추가 원칙: lrclib 싱크 필수 + 실제 가사 표면형 단어 (docs/flutter-plan.md)
- 광고: AdMob **테스트 ID** 사용 중. 리스트 8곡마다, 단어카드 6장마다. 카드형으로 감쌈. 자동재생 시 광고 페이지를 먼저 노출 후 다음 단어.
- 매일 신곡 자동 추가 클라우드 루틴: trig_01JiKKBYq967ssoEifBHhbPv (매일 08:00 KST)
- 곡 끝나면 리스트 다음 곡 자동재생. 맨위로 FAB. 앱바 로고+언어 pill.

## TODO / Follow-up (출시 전 필수)
- **AdMob 실제 ID 발급**: admob.google.com에서 앱(dev.leentj.kpop_hangul) 등록 → App ID + 배너 단위 ID로 교체 (app/lib/utils/ads.dart, AndroidManifest.xml). 현재 테스트 광고라 수익 0.
- **Play Console 출시 준비**: 릴리스 서명 키(keystore) 설정 여부 확인 필요(현재 debug 서명 추정), AAB 빌드, 스토어 등록정보, **개인정보처리방침 URL**(광고 있으면 필수), 콘텐츠 등급.
- 기존 27개 무싱크 곡 일부는 번역 공백 → 영어 대체됨. 필요시 채우기.
