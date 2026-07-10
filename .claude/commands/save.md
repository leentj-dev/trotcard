이 대화에서 진행한 작업 내용을 정리하여 메모리에 저장하는 커맨드입니다.

## 동작

1. 이 대화에서 작업한 내용을 요약합니다:
   - 어떤 기능을 추가/수정/삭제했는지
   - 어떤 파일을 변경했는지
   - 어떤 결정을 내렸는지 (그리고 왜)
   - 해결한 버그나 이슈
   - 남아있는 TODO나 다음 작업

2. 아래 경로에 날짜별 작업 기록 파일을 저장합니다:
   `/Users/leentj/.claude/projects/-Users-leentj-IdeaProjects/memory/`

3. 파일 형식:
   - 파일명: `session_YYYY-MM-DD_간단한설명.md`
   - frontmatter 포함

```markdown
---
name: session-YYYY-MM-DD
description: 한줄 요약
type: project
---

## 작업 내용
- 항목별로 정리

## 변경된 파일
- 파일 경로 + 변경 내용

## 결정 사항
- 결정 내용 + 이유

## TODO / 다음 작업
- 남은 작업
```

4. `MEMORY.md` 인덱스 파일도 업데이트합니다:
   `/Users/leentj/.claude/projects/-Users-leentj-IdeaProjects/memory/MEMORY.md`

## 중요
- 대화 전체를 돌아보고 빠짐없이 기록
- 코드 내용 자체가 아니라 "무엇을 왜 했는지"를 기록
- 다음 세션에서 이어서 작업할 수 있도록 충분한 컨텍스트 제공
