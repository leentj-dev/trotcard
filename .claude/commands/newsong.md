트로트카드 앱에 새 곡(+ 마음 카드 20장)을 추가하는 커맨드입니다.

## 인자: $ARGUMENTS
곡 제목/아티스트, 또는 "list"(현재 곡 목록), 또는 비움.

## 핵심 규칙
- **학습 앱이 아니라 "보내는" 앱** — 곡마다 저작권 없는 **마음 카드 20장**(인사말/축복/명언)을 만든다.
- **가사 직접 인용·번역·변형 금지** (CLAUDE.md). 가사의 낱말은 "재료"로만 참고해 완전히 새로운 문장을 창작한다.
- 곡 데이터는 `app/assets/songs/<id>.json`. 추가/수정 후 반드시 `build_manifest_cards.py`로 매니페스트 재생성 → git push (OTA, 재빌드 불필요).

## 동작

### `$ARGUMENTS`가 "list"인 경우
- `app/assets/songs/manifest.json`을 읽어 현재 곡(id/title/artist/cardCount)을 보여준다.

### `$ARGUMENTS`가 곡 이름/아티스트인 경우
1. **YouTube 영상 ID**를 WebSearch로 찾는다 (공식 무대·음원 영상 우선, 조회수 높은 것).
2. 곡 분위기(mood)를 정한다 — 아래 gradient 키 중 하나로 매핑.
3. **마음 카드 20장**을 창작한다 (아래 카드 규칙).
4. `app/assets/songs/<id>.json` 저장 → `python3 app/scripts/build_manifest_cards.py` 실행 → 결과 확인 후 사용자에게 보고.

## JSON 파일 형식
```json
{
  "id": "artist-title-slug",
  "title": "곡 제목",
  "artist": "아티스트",
  "youtubeId": "YouTube_Video_ID",
  "mood": "sunset",
  "program": "미스터트롯",
  "cards": [
    { "text": "오늘도\n웃음 가득한\n하루 되세요", "emoji": "🌸", "gradient": "spring", "category": "인사" }
  ]
}
```
- `program`은 선택(프로그램 소속 곡만; 미지정이면 키 생략).
- `order`는 넣지 않는다 — `build_manifest_cards.py`가 신규 곡에 자동 부여.

## 카드 규칙 (20장)
- **카드 = 저작권 없는 짧은 인사말/축복/명언.** 가사 구절을 옮기지 말 것.
- `text`: 2~3줄(줄바꿈 `\n`), 시니어가 읽기 쉬운 큰 글씨용 짧은 문장. 따뜻하고 긍정적인 안부.
- `emoji`: 내용에 맞는 이모지 1개.
- `gradient`: 배경 분위기 키 — `sunrise` `spring` `calm` `sunset` `night` `rose` `lavender` `animal` `cafe` `library` 중 하나(곡 mood와 어울리게 분산).
- `category`: `인사` `축복` `명언` `응원` 등 짧은 분류.
- 20장은 서로 다른 문구로 다양하게. 특정 인물·종교·정치 색채는 피하고 보편적 안부로.

## 완료 후
```bash
python3 app/scripts/build_manifest_cards.py   # manifest.json(해시·cardCount) 재생성
git add app/assets/songs/ && git commit -m "feat: 곡 추가 ..." && git push
```
push 하면 유저 앱이 manifest 해시 변화를 감지해 자동 동기화(OTA). 곡/카드 추가는 앱 재빌드 불필요.
