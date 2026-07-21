# trotcard (트로트 카드)

트롯을 들으며 "마음 카드"를 나누는 **시니어(노년층) 대상** 앱.

## 컨셉

카톡에 도는 "좋은 아침이에요 🌸 오늘도 행복하세요" 감성 이미지 문화를 앱으로 옮긴 것.
유튜브로 트롯을 들으면서, 곡 분위기에 맞는 카드를 골라 **이미지(PNG)로 친구에게 공유**한다.

- 학습 앱이 아니다 (kpop-hangul / kdrama 와 다름). 배우는 게 아니라 **보내는** 앱.
- 시니어 대상이라 글자·버튼이 크고 조작이 단순해야 한다.

## Tech Stack

- Flutter (kpop-hangul 엔진을 복제·개조해 시작 — 유튜브 iframe 싱크, AdMob,
  Remote Config, force_update, repository 구조를 재활용)
- youtube_player_iframe — YouTube 공식 임베드 (저작권 안전: 조회수·광고가 원 채널로)
- share_plus — `RepaintBoundary` → PNG 캡처 후 카톡 등으로 공유
- cached_network_image / path_provider — 배경 사진 OTA 다운로드·로컬 캐시
- cloud_firestore — 신청곡 수집 (서버 없이 Firestore 컬렉션만)
- firebase_remote_config — 광고 단위/간격, 카드 자동넘김 초 등 원격 조절
- google_mobile_ads — 3슬롯
- 백엔드 없음: 번들 JSON + GitHub raw 동기화

## 구조

```
app/
  lib/
    main.dart / app.dart        부트스트랩 (MobileAds + Firebase + RC + force_update)
    models/song.dart            Song / SongSummary (cards[], program, viewCount)
    data/song_repository.dart   번들 + GitHub raw 동기화 (manifest hash 변경감지)
    screens/
      feed_screen.dart          곡 목록 + 정렬(최신·인기·제목·가수) + 당겨서새로고침
      song_screen.dart          위 유튜브 재생 + 아래 마음 카드 좌우 스와이프
    widgets/
      greeting_card.dart        카드 렌더·편집·PNG 캡처 공유, 배경 사진 OTA 동기화
      native_ad_card.dart       피드 네이티브 광고
      pager_ads.dart            카드 사이 네이티브 + 카드 아래 배너
      song_request_sheet.dart   신청곡 입력 (Firestore)
    config/                     app_config, remote_config, force_update,
                                build_flags, theme_controller
    utils/                      ads.dart, card_gradients.dart, themes.dart
  assets/
    songs/manifest.json         곡 요약 배열 + hash
    songs/<id>.json             곡 데이터 (카드 20장)
    bg/<분위기>_<n>.jpg          카드 배경 사진 + bg_manifest.json
  scripts/                      매니페스트·조회수·videoId 파이프라인 (아래 참고)
landing/                        홈페이지 (trotcard.twothree.app)
```

## 콘텐츠

- **로스터 97곡** — TJ 노래방 트로트 인기 리스트 기준 (2026-07-13 288곡에서 전면 교체).
  id 는 `kr-<videoId>`, `program` 필드는 비어 있음(평면 구조).
  이전 288곡은 git 태그 `roster-288-20260713-1206` 에 보존.
- **곡당 카드 20장** — 곡의 정서에 맞춘 고유 카드 (분위기 풀 재사용 아님).
- **배경 사진 246장 / 10개 분위기** — sunrise·spring·calm·sunset·night·rose·
  lavender·animal·cafe·library. 출처는 **Pexels**(상업 무료, 출처표기 불필요).

## 파이프라인

```
곡 목록(제목|가수)
  └[scripts/resolve_videos.py]→ videoId  (yt-dlp ytsearch → 임베드되는 최고 조회수본,
                                          oEmbed 200 으로 임베드 가능 검증)
  └[LLM]→ 곡별 원본 카드 20장  (제목·가수·정서만 주고 생성. 가사 미사용)
  └[scripts/build_manifest_cards.py]→ manifest.json 갱신
  └[git push]→ 앱이 자동 반영 (OTA, 재빌드 불필요)
```

- **`scripts/build_manifest.py` 는 kpop 시절 구버전이라 쓰면 안 된다** (words/wordCount
  참조). 반드시 **`build_manifest_cards.py`** 를 쓸 것 — 기존 hash/order 를 보존한다.
- manifest 항목: `{id, title, artist, youtubeId, cardCount, order, viewCount, hash}`.
  **hash = `sha256(곡 JSON 파일 원본 바이트)[:16]`** (파일은
  `json.dumps(ensure_ascii=False, indent=2)` 포맷).
- 조회수는 `scripts/fetch_viewcounts.py` → `viewcounts.json` → 매니페스트에 실림.
  ⚠️ yt-dlp 에 반드시 `--extractor-args "youtube:player_client=android"`
  (web/tv 클라이언트는 "The page needs to be reloaded" 에러).
- **OTA 범위**: 곡·카드·문구·조회수·배경 사진 추가는 push 만으로 반영된다.
  모델(`song.dart`)·피드 UI·새 배경 카테고리는 **코드**라서 재빌드·재배포가 필요하다.
- ⚠️ **`_bundledBgCount`(greeting_card.dart)와 `assets/bg/bg_manifest.json` 은 실제 번들
  장수와 항상 일치시킬 것.** 값이 실제보다 작으면 이미 번들된 사진을 원격에서 또 받는다.
  (현재 셋 다 246 으로 일치.)

## Project Rules

- **저작권 — 가사는 어떤 형태로도 쓰지 않는다.** 인용·번역·변형·재현 전부 금지이고,
  앱 데이터(JSON)에 **가사 원문을 저장하지 않는다**. 카드 문구는 곡의 정서만 참고해
  **직접 창작**한다. (kpop-hangul / kdrama 의 "단어만" 규칙과 같은 계열의 원칙.)
- 영상은 **YouTube 공식 임베드**로만 재생한다.
- 배경 사진은 Pexels License 등 **상업적 사용이 무료인 것만** 쓴다.
- 시니어 대상 UI — 큰 글자, 큰 터치 영역, 단순한 동선.

## 광고 (AdMob 실계정 — publisher `ca-app-pub-6232115093331648`)

3슬롯: 피드 네이티브 / 카드 사이 네이티브(medium) / 카드 아래 배너.

- **App ID** (바꾸면 재빌드 필요): Android `~9989865189` (AndroidManifest
  manifestPlaceholder), iOS `~1485487965` (Info.plist `GADApplicationIdentifier`)
- **광고 단위 ID 는 Remote Config 로 덮어쓴다** → `ads.dart` 하드코딩은 폴백.
  콘솔에서 값만 바꾸면 재빌드 없이 반영된다.
- ⚠️ 실광고라 **본인 클릭 금지** (계정 정지 사유). 테스트는 기기를 testDeviceIds 에 등록.
- 광고가 안 보이면 대개 코드가 아니라 **no-fill** 이다. RC 의 `*_ad_unit_*` 을 구글
  테스트 ID 로 바꿔 배포해 뜨는지 확인하고, **확인 후 반드시 실제 ID 로 복구**할 것.

## 배포

- Firebase 프로젝트 `trotcard` (번호 544354492685). App ID·배포 명령 등 자세한 내용은
  Claude 메모리 `trot-card-firebase` 참고.
- Android 서명: `app/android/key.properties` + `app/android/app/trotcard-release.jks`
  (alias `trot`). 둘 다 gitignore — 커밋 금지.
- 현재 버전 `1.0.0+23`. 스토어 버전 코드는 재사용 불가 → 올릴 때마다 +1.
- ⚠️ `flutter build ... | tail` 처럼 파이프로 넘기면 exit code 가 가려져 실패를 놓친다.
  파이프 없이 돌려 종료코드를 확인할 것.

## ⚠️ 저장소에 남은 kpop-hangul 잔재

이 저장소의 첫 커밋은 `chore: baseline copy from kpop-hangul engine` 이라, **쓰이지 않는
kpop-hangul 파일이 그대로 남아 있다.** 트로트 카드의 실체는 `app/`(Flutter)과
`landing/`(홈페이지)뿐이니 아래는 무시할 것:

- Next.js 일습: `src/`, `next.config.ts`, `package.json`(name 이 아직 `kpop-hangul`),
  `tsconfig.json`, `eslint.config.mjs`, `postcss.config.mjs`, `next-env.d.ts`
- `supabase/`, `.env.local.example`
- `docs/` 안의 kpop 계획·로그 문서
- `.claude/commands/newsong.md`, `syncsong.md` (kpop 곡 파이프라인용)
