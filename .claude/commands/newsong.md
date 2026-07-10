K-pop Hangul 앱에 새 곡을 추가하는 커맨드입니다.

## 인자: $ARGUMENTS

## 핵심 규칙
- **lrclib.net에 syncedLyrics가 있는 곡만 추가합니다**
- LRC가 없는 곡은 추가하지 않고 사용자에게 "LRC 없음"으로 알립니다
- 곡 추가 시 반드시 `/syncsong` 커맨드를 사용합니다

## 동작

### `$ARGUMENTS`가 비어있거나 "chart"인 경우:
1. Billboard Korea Hot 100 차트를 WebFetch로 가져옵니다
2. Supabase에서 기존 곡 목록을 확인합니다 (`npx dotenv -e .env.local -- npx tsx scripts/newsong.ts list`)
3. 차트의 각 곡에 대해 `https://lrclib.net/api/search?q={artist}+{title}` 로 LRC 존재 여부를 확인합니다
4. **LRC가 있고** DB에 없는 곡만 목록으로 보여줍니다 (LRC 없는 곡은 ❌ 표시)
5. 사용자에게 어떤 곡을 추가할지 물어봅니다

### `$ARGUMENTS`가 "list"인 경우:
- `npx dotenv -e .env.local -- npx tsx scripts/newsong.ts list` 실행하여 DB의 곡 목록을 보여줍니다

### `$ARGUMENTS`가 곡 이름/아티스트인 경우:
1. `https://lrclib.net/api/search?q={곡 이름}` 에서 syncedLyrics 존재 여부를 확인합니다
2. **syncedLyrics가 없으면**: "이 곡은 LRC 싱크 가사가 없어서 추가할 수 없습니다" 안내 후 중단
3. **syncedLyrics가 있으면**: 아래 일괄 추가 스크립트 방식으로 바로 추가합니다

### `$ARGUMENTS`가 "all"인 경우:
- 차트에서 LRC가 있는 새 곡을 모두 찾아서 일괄 추가합니다

## 일괄 추가 방식 (사용자 확인 없이 바로 실행)
LRC가 확인된 곡은 아래 node 스크립트로 한번에 처리합니다:
1. lrclib.net에서 LRC 파싱 → 1마디(4박) 간격 그리드로 곡 전체에 촘촘히 단어 배치 (간격초 = 4×60/BPM)
2. YouTube MV ID를 WebSearch로 검색
3. 7개국어 번역 + romanization + emoji + example 생성
4. `app/assets/songs/`에 JSON 파일 저장 → `python3 app/scripts/build_manifest.py` 실행(manifest 해시 자동 갱신)
5. 사용자 확인 없이 자동으로 모두 추가 (MV 오프셋은 0으로, 나중에 조정)

## LRC 확인 방법
```bash
curl -s "https://lrclib.net/api/search?q={artist}+{title}" | node -e "
const chunks=[];
process.stdin.on('data',c=>chunks.push(c));
process.stdin.on('end',()=>{
  const d=JSON.parse(Buffer.concat(chunks).toString());
  const match=d.find(x=>x.syncedLyrics);
  if(match) console.log('LRC_OK|'+match.id+'|'+match.artistName+' - '+match.trackName);
  else console.log('NO_LRC');
});
"
```

## JSON 파일 형식

songs/ 디렉토리에 저장하는 JSON 형식:
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

## 단어 규칙 (1마디 그리드)
- **1마디(measure)마다 단어 1개** — 곡 박자(보통 4/4 → 1마디 4박)에 맞춰 1마디=4박마다 카드 하나씩. 간격(초) = 4 × 60 / BPM (부르는 거의 모든 한국어 가사 줄에 카드)
- BPM은 웹에서 `{artist} {title} BPM` 조회(songbpm.com/tunebat), 박자표는 특별한 경우 아니면 4/4 가정
- 곡 처음부터 끝까지 **균등 배치** (앞쪽 몰림 금지): 첫 가사 줄부터 시작해, "직전 선택 시각 + 간격" 이상인 다음 가사 줄을 차례로 선택
- 각 지점에서 그때 불리는 의미 있는 한국어 단어 1개 선택 (다른 지점에서 같은 단어가 또 나오는 중복은 허용)
- LRC 가사에서 실제로 나오는 한국어 단어만 사용
- 7개국어 번역을 모두 채움: english, spanish, portuguese, indonesian, japanese, thai, french (빈 문자열 금지 — 각 언어로 단어 뜻을 번역)
- timestamp는 lrclib.net의 LRC 타이밍 기반 + MV 오프셋
