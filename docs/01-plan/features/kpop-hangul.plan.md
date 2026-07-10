# kpop-hangul Planning Document

> **Summary**: K-pop 단어/숙어로 한글을 배우는 외국인 대상 학습 앱
>
> **Project**: kpop-hangul
> **Version**: 0.1.0
> **Author**: leentj
> **Date**: 2026-03-13
> **Status**: Draft

---

## Executive Summary

| Perspective | Content |
|-------------|---------|
| **Problem** | 외국인이 한글을 배울 때 동기부여가 부족하고, 기존 학습 앱은 K-pop 팬의 관심사를 활용하지 못함 |
| **Solution** | K-pop 노래에서 자주 쓰이는 단어/숙어를 중심으로 한글 학습 콘텐츠를 제공하고, YouTube 링크로 실제 노래와 연결 |
| **Function/UX Effect** | 카드 기반 단어 학습 + 퀴즈로 게임화된 학습 경험 제공 (로그인 없이 바로 시작) |
| **Core Value** | K-pop이라는 강력한 동기부여 요소를 활용해 한글 학습의 진입 장벽을 낮추고 지속적 학습을 유도 |

---

## 1. Overview

### 1.1 Purpose

K-pop에 관심 있는 외국인이 좋아하는 음악에 나오는 단어와 숙어를 통해 자연스럽게 한글을 배울 수 있도록 한다. 기존 한국어 학습 앱과 차별화하여 K-pop 팬덤을 학습 동기로 활용한다.

### 1.2 Background

- 전 세계 K-pop 팬덤이 급격히 성장 중
- 많은 K-pop 팬들이 가사를 이해하고 싶어하지만 한글 진입장벽이 높음
- 기존 학습 앱(Duolingo 등)은 K-pop 맥락을 활용하지 않음
- 저작권 문제 없이 단어/숙어/노래 제목/YouTube 링크만으로 구성 가능

### 1.3 Related Documents

- CLAUDE.md (프로젝트 규칙)

---

## 2. Scope

### 2.1 In Scope

- [x] 자음/모음 학습 (한글 기초)
- [x] K-pop 단어 카드 학습 (카테고리별)
- [x] K-pop 숙어/표현 학습
- [x] 단어가 나오는 노래 정보 + YouTube 링크
- [x] 퀴즈 모드 (뜻 맞추기, 발음 맞추기)
- [x] 즐겨찾기 (내 단어장) — localStorage 저장
- [x] 학습 진도 추적 — localStorage 저장

### 2.2 Out of Scope

- 회원가입 / 로그인 (v2에서 고려)
- 가사 전체 표시 (저작권 문제)
- 음원/영상 직접 재생 (YouTube 링크로 대체)
- 커뮤니티/채팅 기능
- 음성 인식 발음 평가
- 유료 결제 / 프리미엄 기능

---

## 3. Requirements

### 3.1 Functional Requirements

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| FR-01 | 자음(ㄱ-ㅎ)/모음(ㅏ-ㅣ) 학습 카드 | High | Pending |
| FR-02 | K-pop 단어 카드 (한글 + 로마자 발음 + 영어 뜻 + 이모지) | High | Pending |
| FR-03 | 카테고리별 단어 분류 (사랑, 감정, 자연, 시간, 일상, 인사, 음식) | High | Pending |
| FR-04 | 단어별 연관 노래 정보 (노래 제목 + 아티스트 + YouTube 링크) | High | Pending |
| FR-05 | K-pop 숙어/관용 표현 학습 | Medium | Pending |
| FR-06 | 퀴즈 모드 (4지선다 뜻 맞추기) | High | Pending |
| FR-07 | 퀴즈 모드 (발음 보고 한글 맞추기) | Medium | Pending |
| FR-08 | 즐겨찾기 (내 단어장) — localStorage 저장 | Medium | Pending |
| FR-09 | 학습 진도 저장 및 표시 — localStorage 저장 | Medium | Pending |
| FR-10 | 다크모드 지원 | Low | Pending |

### 3.2 Non-Functional Requirements

| Category | Criteria | Measurement Method |
|----------|----------|-------------------|
| Performance | 페이지 로딩 < 2초 | Lighthouse |
| Responsive | 모바일/태블릿/데스크톱 반응형 | 수동 테스트 |
| Accessibility | 영어 UI, WCAG 2.1 AA | Lighthouse |
| SEO | 메타 태그, OG 태그 적용 | Lighthouse |

---

## 4. Success Criteria

### 4.1 Definition of Done

- [ ] 모든 High priority 요구사항 구현 완료
- [ ] 최소 50개 K-pop 단어 데이터 입력
- [ ] 최소 20개 숙어 데이터 입력
- [ ] 퀴즈 기능 정상 작동
- [ ] 모바일 반응형 확인
- [ ] 코드 리뷰 완료

### 4.2 Quality Criteria

- [ ] Zero lint errors
- [ ] Build succeeds
- [ ] 주요 기능 수동 테스트 통과

---

## 5. Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| 저작권 침해 (가사 인용) | High | Low | 단어/숙어만 사용, 가사 직접 인용 금지 규칙 엄수 |
| YouTube 링크 만료 | Low | Medium | 공식 채널 링크 우선 사용, 주기적 링크 점검 |
| 단어 데이터 부족 | Medium | Low | 카테고리별 최소 10개씩 확보 후 점진적 추가 |
| localStorage 용량 제한 | Low | Low | 필요 시 IndexedDB로 전환 |

---

## 6. Architecture Considerations

### 6.1 Project Level Selection

| Level | Characteristics | Recommended For | Selected |
|-------|-----------------|-----------------|:--------:|
| **Starter** | Simple structure | Static sites, portfolios | ☑ |
| **Dynamic** | Feature-based, BaaS integration | Web apps with backend | ☐ |
| **Enterprise** | Strict layer separation, microservices | High-traffic systems | ☐ |

### 6.2 Key Architectural Decisions

| Decision | Options | Selected | Rationale |
|----------|---------|----------|-----------|
| Framework | Next.js / React / Vue | Next.js 14+ (App Router) | SSR + 파일 기반 라우팅 |
| State Management | Context / Zustand / Redux | Zustand | 가볍고 간단한 API |
| Data Storage | localStorage / BaaS / DB | localStorage | 회원가입 없이 클라이언트 저장 |
| Styling | Tailwind / CSS Modules | Tailwind CSS | 빠른 UI 개발 |

### 6.3 Clean Architecture Approach

```
Selected Level: Starter (with Zustand)

Folder Structure:
┌─────────────────────────────────────────────────────┐
│ src/                                                │
│   app/                   # Next.js App Router       │
│     learn/               # 자음/모음 + 단어 학습      │
│     words/               # 단어 목록 (카테고리별)      │
│     idioms/              # 숙어/표현 학습             │
│     quiz/                # 퀴즈                      │
│     favorites/           # 즐겨찾기 (내 단어장)       │
│   components/ui/         # Button, Card 등           │
│   components/features/   # WordCard, QuizCard 등     │
│   hooks/                 # useProgress, useFavorites │
│   stores/                # Zustand stores            │
│   types/                 # TypeScript types          │
│   data/                  # 단어/숙어 JSON 데이터      │
└─────────────────────────────────────────────────────┘
```

---

## 7. Convention Prerequisites

### 7.1 Existing Project Conventions

- [x] `CLAUDE.md` has coding conventions section
- [ ] `docs/01-plan/conventions.md` exists
- [x] ESLint configuration (`.eslintrc.*`)
- [x] TypeScript configuration (`tsconfig.json`)

### 7.2 Conventions to Define/Verify

| Category | Current State | To Define | Priority |
|----------|---------------|-----------|:--------:|
| **Naming** | missing | 컴포넌트: PascalCase, 파일: kebab-case, 변수: camelCase | High |
| **Folder structure** | exists | Dynamic 레벨 구조 준수 | High |
| **Import order** | missing | React → Next → 외부 → 내부 → 타입 | Medium |
| **Environment variables** | exists | NEXT_PUBLIC_ prefix 규칙 | Medium |

### 7.3 Environment Variables Needed

| Variable | Purpose | Scope | To Be Created |
|----------|---------|-------|:-------------:|
| (없음 — 백엔드 불필요) | - | - | - |

---

## 8. 콘텐츠 전략

### 8.1 단어 카테고리 및 예시

| Category | 한국어 | 예시 단어 | 이모지 |
|----------|--------|----------|--------|
| Love (사랑) | 사랑, 마음, 눈물, 키스, 약속 | 사랑 = Love | ❤️ |
| Emotion (감정) | 행복, 슬픔, 외로움, 그리움, 설렘 | 행복 = Happiness | 😊 |
| Nature (자연) | 하늘, 별, 달, 바다, 꽃 | 하늘 = Sky | 🌸 |
| Time (시간) | 오늘, 내일, 영원, 밤, 순간 | 영원 = Forever | ⏰ |
| Daily (일상) | 친구, 학교, 집, 꿈, 길 | 꿈 = Dream | 🏠 |
| Greeting (인사) | 안녕, 감사, 미안, 축하, 파이팅 | 안녕 = Hello | 👋 |
| Food (음식) | 밥, 김치, 떡볶이, 치킨, 커피 | 김치 = Kimchi | 🍚 |

### 8.2 숙어/표현 예시

| 한국어 | Romanization | English | Literal |
|--------|-------------|---------|---------|
| 마음을 열다 | ma-eum-eul yeol-da | To open one's heart | Open heart |
| 사랑에 빠지다 | sa-rang-e ppa-ji-da | To fall in love | Fall into love |
| 눈이 높다 | nun-i nop-da | To have high standards | Eyes are high |
| 힘을 내다 | him-eul nae-da | To cheer up | Put out strength |
| 꿈을 꾸다 | kkum-eul kku-da | To dream | Dream a dream |

### 8.3 저작권 안전 규칙

- ✅ 개별 단어 사용 (저작권 없음)
- ✅ 일반적 숙어/관용구 사용 (저작권 없음)
- ✅ 노래 제목 + 아티스트명 표시 (저작권 없음)
- ✅ YouTube 링크 연결 (합법)
- ✅ Unsplash/Pexels 이미지 사용 (무료 라이선스)
- ❌ 가사 전체/부분 인용 금지
- ❌ 음원/영상 직접 삽입 금지
- ❌ 연예인 사진 사용 금지

---

## 9. Next Steps

1. [ ] Design 문서 작성 (`/pdca design kpop-hangul`)
2. [ ] 단어/숙어 JSON 데이터 준비
3. [ ] UI 목업 작성
4. [ ] 구현 시작

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 0.1 | 2026-03-13 | Initial draft | leentj |
| 0.2 | 2026-03-13 | 회원가입 제거, Starter 레벨로 변경, localStorage 저장 | leentj |
