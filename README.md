# 트로트카드 (trotcard)

트롯을 들으며 "마음 카드"를 나누는 **시니어(노년층) 대상** 앱 (Flutter).
카톡에 도는 "좋은 아침이에요 🌸" 감성 안부 이미지 문화를 앱으로 옮긴 것 — 유튜브로
트롯을 들으면서 곡 분위기에 맞는 카드를 골라 **이미지(PNG)로 친구에게 공유**한다.

- 학습 앱이 아니라 **보내는** 앱. 시니어 대상이라 글자·버튼이 크고 조작이 단순하다.
- 저작권 없는 콘텐츠만 사용 (가사 직접 인용 금지).

## 구조

- `app/` — Flutter 앱 (본체). 자세한 내용은 [`CLAUDE.md`](CLAUDE.md) 및 [`app/README.md`](app/README.md).
- `landing/` — 랜딩/개인정보 페이지 (trotcard.twothree.app).
- `firestore.rules` / `firebase.json` — 신청곡 수집용 Firestore 설정.

## 곡·카드 추가 (OTA)

곡과 카드는 `app/assets/songs/<id>.json`. 수정 후 `app/scripts/build_manifest_cards.py`로
매니페스트를 재생성해 push 하면 앱이 자동 동기화한다(재빌드 불필요). `/newsong` 커맨드 참고.
