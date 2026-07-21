K-pop Hangul 앱에 LRC 싱크 가사 기반으로 곡을 추가하는 커맨드입니다.

## 인자: $ARGUMENTS

## 동작

### 1단계: 곡 정보 확인
- `$ARGUMENTS`에서 아티스트명과 곡 제목을 파악합니다
- YouTube에서 해당 곡의 official MV video ID를 WebSearch로 검색합니다

### 2단계: LRC 싱크 가사 가져오기
- `https://lrclib.net/api/search?q={artist}+{title}` 에서 LRC 데이터를 검색합니다
- 검색 결과에서 해당 곡의 ID를 찾습니다
- `https://lrclib.net/api/get/{id}` 에서 syncedLyrics를 가져옵니다
- Bash로 curl + node를 사용하여 LRC 타임스탬프를 파싱합니다:
```
curl -s "https://lrclib.net/api/get/{id}" | node -e "
const chunks = [];
process.stdin.on('data', c => chunks.push(c));
process.stdin.on('end', () => {
  const data = JSON.parse(Buffer.concat(chunks).toString());
  const lines = data.syncedLyrics.split('\n');
  lines.forEach(line => {
    const match = line.match(/\[(\d+):(\d+\.\d+)\]\s*(.*)/);
    if (match && match[3].trim()) {
      const secs = parseInt(match[1]) * 60 + parseFloat(match[2]);
      console.log(secs.toFixed(1) + ' | ' + match[3].trim());
    }
  });
});
"
```

### 3단계: MV 오프셋 계산
- 사용자에게 MV에서 첫 가사가 나오는 시간(초)을 물어봅니다
- LRC의 첫 가사 시간과 비교하여 오프셋을 계산합니다
- 오프셋 = MV시간 - LRC시간 - 1초 (1초 앞당김 적용)

### 4단계: 단어 선택 (1마디 그리드)
- **1마디(measure)마다 단어 1개**: 곡 박자(보통 4/4 → 1마디 4박)에 맞춰 1마디=4박마다 카드 하나씩. 간격(초) = 4 × 60 / BPM (부르는 거의 모든 한국어 가사 줄에 카드)
- BPM은 웹에서 `{artist} {title} BPM` 조회(songbpm.com/tunebat), 박자표는 특별한 경우 아니면 4/4 가정
- 곡 처음부터 끝까지 **균등 배치** (앞쪽 몰림 금지): 첫 가사 줄부터, "직전 선택 시각 + 간격" 이상인 다음 가사 줄을 차례로 선택
- 선택 기준:
  - 그 시각 가사 줄에서 명확하게 들리는 단어
  - noun, verb, adjective 골고루, 한국어 학습에 유용한 일상 단어 우선
  - 다른 지점에서 같은 단어가 또 나오는 중복은 허용

### 5단계: JSON 파일 생성
- 각 단어에 대해 7개국어 번역을 생성합니다
- 타임스탬프 = LRC시간 + 오프셋
- `app/assets/songs/` 디렉토리에 JSON 파일을 저장합니다
- **저장 후 `python3 app/scripts/build_manifest_cards.py` 실행** → `manifest.json`(cardCount·해시 포함)을 자동 재생성. manifest는 직접 편집 금지 — 반드시 이 스크립트로 생성해야 유저 앱이 변경을 감지해 자동 동기화함

```json
{
  "id": "artist-title-slug",
  "title": "곡 제목",
  "artist": "아티스트",
  "youtubeId": "YouTube_Video_ID",
  "words": [
    {
      "korean": "단어",
      "romanization": "ro-ma-ni-za-tion",
      "english": "English",
      "spanish": "Spanish",
      "portuguese": "Portuguese",
      "indonesian": "Indonesian",
      "japanese": "Japanese",
      "thai": "Thai",
      "french": "French",
      "partOfSpeech": "noun",
      "emoji": "🎵",
      "example": "한국어 예문",
      "exampleTranslation": "English translation",
      "timestamp": 46
    }
  ]
}
```

### 6단계: DB 삽입
```
npx dotenv -e .env.local -- npx tsx scripts/newsong.ts add songs/<file>.json
```

### 7단계: 확인
- 사용자에게 결과 테이블을 보여줍니다 (MV시간 | 단어 | 뜻)
- 타임스탬프 미세 조정이 필요하면 사용자 피드백을 받아 수정합니다

## 단어 생성 규칙
- **1마디(4박)마다 단어 1개**, 곡 전체에 촘촘히 배치 (간격초 = 4×60/BPM). 앞쪽 몰림 금지
- 다른 지점에서 같은 단어가 또 나오는 중복은 허용
- 7개국어 번역을 모두 채움: english, spanish, portuguese, indonesian, japanese, thai, french (빈 문자열 금지 — 각 언어로 단어 뜻을 번역)
- 이모지는 단어 의미에 맞게
- 예문은 해당 가사 라인 사용 (저작권상 한 줄 이내)
