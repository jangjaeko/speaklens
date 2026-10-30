# CLAUDE.md

> English version first, Korean version below. / 영어 버전이 먼저, 한국어 버전은 아래에 있습니다.

This document is the reference Claude Code uses when working on this project. Read it before starting any task and follow the direction and rules described here.

---

## 1. Project Overview

**Name (working title):** SpeakLens

A web app that records a conversation, isolates only my speech, and:
- shows statistics on the words I use most, my filler words/verbal habits, and my speaking style
- corrects grammar mistakes in English conversations and suggests more natural expressions.

**Background:** A tool I need myself as someone working and interviewing in English in Canada.

**Purpose:** A job-search portfolio project, targeting companies that use Rails (e.g., Clio).
- **Polish, a deployed demo, and a README that explains design decisions** matter more than the number of features.
- Target timeline: **2 weeks** (core of Phases 1–2 complete + deployed).

---

## 2. About Me / How to Work With Me (Important)

- I am **learning Rails**. Speed matters, but I must be able to **explain every line of code in an interview**.
- Whenever you write code, **briefly explain the key Rails concept in 2–3 lines** (e.g., why you used `after_commit`, and what the alternatives were).
- For concepts appearing for the first time (first model/migration, first controller, first Active Job, first Hotwire integration), **don't write it all at once**. Explain the approach first, then give me a skeleton or hints so I can write it myself.
- Repetitive work, configuration, and boilerplate can be written directly.
- For large features, **propose a plan before implementing** and get my confirmation. If I bring my own plan, review it and point out what's missing.
- Keep commits **small and feature-scoped**.
- Summarize problems I got stuck on and how they were solved, so I can record them in `LEARNING.md`.

---

## 3. Tech Stack

- **Ruby / Rails:** Latest stable version (Rails 8 baseline — confirm the version at start)
- **DB:** PostgreSQL (use `jsonb` for analysis results)
- **Frontend:** Hotwire (Turbo + Stimulus), prefer Rails defaults
- **File storage:** Active Storage
- **Background jobs:** Active Job + Solid Queue
- **Real-time UI updates:** Turbo Streams
- **Recording:** Browser MediaRecorder API (Stimulus controller)
- **STT:** An API that supports speaker diarization (AssemblyAI or Deepgram — check the latest docs for features, pricing, and supported formats before starting)
- **LLM:** Only for grammar correction and expression suggestions (e.g., Claude API). Use schema-enforced structured output (tool use / structured output)
- **Testing:** Rails default (Minitest)
- **Deployment:** Deploy an empty app in week 1 (Kamal or Render/Fly.io, etc. — decide at start)

**Principle:** Only add external gems when truly necessary, and explain why when adding one. If Rails defaults can do it, use the defaults.

---

## 4. Overall Flow

```mermaid
flowchart LR
  A[Browser recording] --> B[Upload<br/>Active Storage]
  B --> C[STT Job<br/>with diarization]
  C --> D[Speaker selection<br/>"I am A"]
  D --> E[Statistics<br/>Ruby code]
  D --> F[Grammar/expressions<br/>LLM, JSON]
  E --> G[Persist<br/>PostgreSQL]
  F --> G
  G --> H[Dashboard<br/>Turbo Streams updates]
```

1. User checks the recording consent box, then records in the browser
2. Recording ends → file upload (Active Storage)
3. Background job calls the STT API → saves utterances per speaker
4. User selects "I am speaker A"
5. For my utterances:
   - **Word frequency → computed in Ruby code; verbal habits → labeled by the LLM in context, counted in Ruby (ADR 003)**
   - **Grammar correction and expression suggestions → analyzed by LLM (JSON response)**
6. Processing status (processing → done) updates automatically via Turbo Streams
7. Cumulative dashboard shows statistics and correction history

---

## 5. Key Design Decisions (recorded as ADRs in `docs/decisions/`)

1. **Speaker diarization is delegated to the STT API, not built in-house.** The user only selects their own speaker label from the results.
2. **The LLM judges, code counts.** Whether a phrase is a verbal habit depends on context ("I'm, like, really" vs. "I like Rails"), so the LLM labels each occurrence; Ruby validates and tallies them so numbers are accurate and reproducible. Word frequency is pure code. The LLM also does grammar correction, expression suggestions, and style feedback. (Revised 2026-10-30, ADR 003.)
3. **LLM responses follow a fixed JSON schema and are validated before saving.** If the format breaks, retry or mark as failed.
4. **Analysis focuses on English.** Korean requires morphological analysis and is out of scope. (Possibly handle a few Korean fillers with regex after Phase 3.)
5. **Privacy is designed as a feature.** (See section 7.)

---

## 6. Data Model (Draft — review together before implementing)

- **User**
- **Recording**: `user_id`, audio file (Active Storage), `status` (uploaded / transcribing / awaiting_speaker / analyzing / completed / failed), `duration_seconds`, `language`, `my_speaker_label`, `consent_confirmed_at`, `audio_deleted_at`
- **Utterance**: `recording_id`, `speaker_label`, `text`, `start_ms`, `end_ms`, `mine` (boolean)
- **Analysis**: `recording_id`, `word_stats` (jsonb), `filler_stats` (jsonb), `status`
- **Correction**: `analysis_id`, `utterance_id`, `original`, `corrected`, `explanation`, `suggested_expression`, `category` (grammar / naturalness, etc.)

Corrections are stored as individual records to support the review feature (Phase 3).

---

## 7. Privacy Features

- Before recording: **"Please let the other person know you're recording" notice + consent checkbox** (recording is disabled until checked)
- **Option to auto-delete the original audio** after transcription
- **Option to keep only my utterances and discard the other person's after analysis**
- Never log API keys or personal data.
- Recording laws vary by region, so the app frames this as **"designed to prompt for consent"** rather than making legal judgments.

---

## 8. Demo Mode and Cost Limits

- Provide a **demo account with pre-analyzed sample conversations** via seeds (interviewers can try it without recording)
- Recording length limit (e.g., max 5 minutes)
- Daily analysis limit per user
- During development, test with short recordings and, where possible, save API responses as fixtures for reuse in tests

---

## 9. Scope and Schedule

### Phase 1 (MVP)
- Record → upload → STT (diarization) → speaker selection → show analysis results

### Phase 2
- Cumulative stats: most-used words, verbal-habit frequency ("like", "you know", "I mean", etc.; "um"/"uh" are out of scope, see ADR 001), changes over time
- If short on time, **replace charts with tables**

### Phase 3 (after 2 weeks, if time allows)
- Live captions, review/practice of incorrect sentences, partial support for Korean fillers

### 2-Week Plan
- **Week 1:** Rails fundamentals → deploy empty app → recording upload (Active Storage) → STT job (Active Job) → status updates via Turbo Streams
- **Week 2:** Speaker selection → statistics (code) → LLM corrections/suggestions → dashboard → demo account → tests → README

**Priority:** The end-to-end flow "record → select speaker → filler stats → grammar correction" working is the top priority. Extras come after.

---

## 10. Known Pitfalls

- Recording formats differ by browser (Chrome: usually webm, Safari: usually mp4). Confirm on day one that the chosen STT API accepts both.
- API keys, background job execution, and file storage config can break separately in production, so **deploy in week 1**.
- All external API calls run in background jobs, with retries and visible failure states.

---

## 11. Docs and Task Management

- `CLAUDE.md` — this document (project reference)
- `docs/` — feature designs, data model
- `docs/decisions/` — ADRs (e.g., `001-diarization-via-api.md`)
- `LEARNING.md` — daily notes on concepts learned, blockers, and solutions
- `README.md` — demo link/account, architecture diagram, design rationale, problems and how they were solved
- Kanban: **GitHub Projects** (link Issues with commits/PRs)

Workflow: start a feature → plan (plan mode) → save to an issue or `docs/` → implement → small commits → update ADR / LEARNING.md as needed

---

## 12. Coding Conventions

- Follow Rails conventions (Convention over Configuration).
- Put external API integration logic in service objects (`app/services/`) (e.g., `Transcription::Client`, `Feedback::Analyzer`).
- Write statistics logic as plain Ruby classes with unit tests.
- Manage secrets with Rails credentials or environment variables; never commit them.
- Variable/method names, commit messages, and README/docs in the repo are written in **English**.

---
---

# CLAUDE.md (한국어)

이 문서는 Claude Code가 이 프로젝트에서 작업할 때 참고하는 기준 문서야. 작업 시작 전에 항상 읽고, 여기 적힌 방향과 규칙을 따라줘.

---

## 1. 프로젝트 개요

**이름(가칭):** SpeakLens

대화를 녹음하면 내 말만 골라서
- 자주 쓰는 단어, 말버릇(습관어), 말투를 통계로 보여주고
- 영어 대화의 문법 오류를 교정하고, 더 자연스러운 표현을 추천해주는 웹앱.

**배경:** 캐나다에서 영어로 일하고 면접을 보는 내가 직접 필요해서 만드는 도구.

**목적:** 취업용 포트폴리오. Rails를 사용하는 회사(예: Clio) 지원용.
- 기능 개수보다 **완성도, 배포된 데모, 설계 판단을 설명하는 README**가 중요하다.
- 목표 기간: **2주** (1~2단계 핵심 기능 완성 + 배포).

---

## 2. 나에 대해 / 작업 방식 (중요)

- 나는 **Rails를 배우는 중**이다. 속도도 중요하지만, 내가 모든 코드를 **면접에서 직접 설명할 수 있어야** 한다.
- 코드를 작성할 때마다 **핵심 Rails 개념을 2~3줄로 짧게 설명**해줘. (예: 왜 `after_commit`을 썼는지, 다른 선택지는 뭐였는지)
- 새로운 개념이 처음 등장하는 부분(첫 모델/마이그레이션, 첫 컨트롤러, 첫 Active Job, 첫 Hotwire 연동)은 **바로 다 짜지 말고**, 먼저 접근 방법을 설명하고 내가 직접 짜볼 수 있도록 뼈대나 힌트를 줘.
- 비슷한 작업의 반복이나 설정, 보일러플레이트는 바로 작성해도 된다.
- 큰 기능은 구현 전에 **계획을 먼저 제시**하고 내 확인을 받아줘. 내가 먼저 계획을 적어오면 검토하고 빠진 점을 알려줘.
- 커밋은 **기능 단위로 작게** 나눠줘.
- 막혔던 문제와 해결 과정은 `LEARNING.md`에 기록할 수 있도록 요약해줘.

---

## 3. 기술 스택

- **Ruby / Rails:** 최신 안정 버전 (Rails 8 기준, 시작 시 버전 확인)
- **DB:** PostgreSQL (분석 결과는 `jsonb` 활용)
- **프론트엔드:** Hotwire (Turbo + Stimulus), Rails 기본 구성 우선
- **파일 저장:** Active Storage
- **백그라운드 작업:** Active Job + Solid Queue
- **실시간 화면 갱신:** Turbo Streams
- **녹음:** 브라우저 MediaRecorder API (Stimulus 컨트롤러)
- **STT:** 화자 분리(diarization)를 지원하는 API (AssemblyAI 또는 Deepgram 중 선택 — 시작 전에 최신 문서로 기능/요금/지원 포맷 확인)
- **LLM:** 문법 교정 및 표현 추천 전용 (Claude API 등). 스키마를 강제하는 구조화 출력(tool use / structured output) 사용
- **테스트:** Rails 기본(Minitest)
- **배포:** 첫 주에 빈 앱이라도 먼저 배포 (Kamal 또는 Render/Fly.io 등 — 시작 시 결정)

**원칙:** 외부 gem은 꼭 필요할 때만 추가하고, 추가할 때 이유를 설명해줘. Rails 기본 기능으로 되는 건 기본 기능을 쓴다.

---

## 4. 전체 흐름

(다이어그램은 영어 버전 4번 참고)

1. 사용자가 녹음 동의 체크 후 브라우저에서 녹음
2. 녹음 종료 → 파일 업로드 (Active Storage)
3. 백그라운드 Job이 STT API 호출 → 화자별 발화(Utterance) 저장
4. 사용자가 "이 중에 나는 A"를 선택
5. 내 발화에 대해:
   - **단어 빈도 → Ruby 코드로 계산, 습관어 → LLM이 문맥으로 판별하고 Ruby가 집계 (ADR 003)**
   - **문법 교정, 추천 표현 → LLM으로 분석 (JSON 응답)**
6. 처리 상태(처리 중 → 완료)는 Turbo Streams로 자동 갱신
7. 누적 대시보드에서 통계와 교정 내역 확인

---

## 5. 핵심 설계 결정 (ADR로 `docs/decisions/`에 기록)

1. **화자 분리는 직접 구현하지 않고 STT API에 맡긴다.** 사용자는 결과에서 자신의 화자 라벨만 선택한다.
2. **판단은 LLM, 집계는 코드.** 습관어인지는 문맥에 달려 있으므로("I'm, like, really" vs "I like Rails") LLM이 각 위치를 표시하고, Ruby가 검증·집계해 숫자를 정확하고 재현 가능하게 만든다. 단어 빈도는 순수 코드. LLM은 문법 교정, 표현 추천, 말투 피드백도 맡는다. (2026-10-30 수정, ADR 003)
3. **LLM 응답은 정해진 JSON 스키마로 받고 검증 후 저장한다.** 형식이 깨지면 재시도 또는 실패 상태로 처리한다.
4. **분석 언어는 영어에 집중한다.** 한국어는 형태소 분석이 필요해 범위 밖이다. (필요 시 습관어 몇 개만 정규식으로 처리하는 정도로 3단계 이후 검토)
5. **개인정보 보호를 기능으로 설계한다.** (아래 7번 참고)

---

## 6. 데이터 모델 (초안 — 구현 전에 같이 검토)

- **User**
- **Recording**: `user_id`, 오디오 파일(Active Storage), `status`(uploaded / transcribing / awaiting_speaker / analyzing / completed / failed), `duration_seconds`, `language`, `my_speaker_label`, `consent_confirmed_at`, `audio_deleted_at`
- **Utterance**: `recording_id`, `speaker_label`, `text`, `start_ms`, `end_ms`, `mine`(boolean)
- **Analysis**: `recording_id`, `word_stats`(jsonb), `filler_stats`(jsonb), `status`
- **Correction**: `analysis_id`, `utterance_id`, `original`, `corrected`, `explanation`, `suggested_expression`, `category`(grammar / naturalness 등)

복습 기능(3단계)을 고려해 Correction은 개별 레코드로 저장한다.

---

## 7. 개인정보 보호 기능

- 녹음 시작 전 **"상대방에게 녹음 사실을 알려주세요" 안내 + 동의 체크** (체크해야 녹음 가능)
- 텍스트 변환 후 **원본 음성 자동 삭제 옵션**
- **내 발화만 저장하고 상대방 발화는 분석 후 폐기하는 옵션**
- API 키, 개인정보는 로그에 남기지 않는다.
- 녹음 관련 법은 지역마다 다르므로, 앱은 법적 판단이 아니라 **"동의를 받도록 안내하는 설계"**로 표현한다.

---

## 8. 데모 모드와 비용 제한

- 샘플 대화가 **미리 분석된 데모 계정**을 seed로 제공 (면접관이 녹음 없이 체험 가능)
- 녹음 길이 제한 (예: 최대 5분)
- 사용자별 일일 분석 횟수 제한
- 개발 중에는 짧은 녹음으로 테스트하고, 가능하면 API 응답을 fixture로 저장해 테스트에 재사용

---

## 9. 범위와 일정

### 1단계 (MVP)
- 녹음 → 업로드 → STT(화자 분리) → 화자 선택 → 분석 결과 표시

### 2단계
- 누적 통계: 자주 쓰는 단어 순위, 습관어 빈도("like", "you know", "I mean" 등. "um"/"uh"는 범위 밖, ADR 001 참고), 시간에 따른 변화
- 시간이 부족하면 차트 대신 **표로 대체**해도 된다

### 3단계 (2주 이후, 여유 있을 때)
- 실시간 자막, 틀린 문장 복습/연습 기능, 한국어 습관어 일부 지원

### 2주 계획
- **1주차:** Rails 기본기 → 빈 앱 배포 → 녹음 업로드(Active Storage) → STT Job(Active Job) → Turbo Streams로 상태 갱신
- **2주차:** 화자 선택 → 통계(코드) → LLM 교정/추천 → 대시보드 → 데모 계정 → 테스트 → README

**우선순위:** "녹음 → 화자 선택 → 습관어 통계 → 문법 교정"이 끝까지 동작하는 것이 최우선. 부가 기능은 그다음.

---

## 10. 미리 알고 있는 주의점

- 브라우저별 녹음 포맷이 다르다 (Chrome: 보통 webm, Safari: 보통 mp4). 선택한 STT API가 두 포맷을 모두 받는지 첫날 확인한다.
- 배포 환경에서 API 키, 백그라운드 작업 실행, 파일 저장소 설정이 따로 꼬일 수 있으므로 **배포는 첫 주에** 한다.
- 외부 API 호출은 모두 백그라운드 Job에서 하고, 실패 시 재시도와 실패 상태 표시를 처리한다.

---

## 11. 문서와 작업 관리

- `CLAUDE.md` — 이 문서 (프로젝트 기준)
- `docs/` — 기능 설계, 데이터 모델
- `docs/decisions/` — ADR (예: `001-diarization-via-api.md`)
- `LEARNING.md` — 매일 배운 개념, 막힌 문제, 해결 방법
- `README.md` — 데모 링크/계정, 구조도, 설계 이유, 막혔던 문제와 해결 과정
- 칸반: **GitHub Projects** (Issues와 커밋/PR 연결)

작업 흐름: 기능 시작 → 계획 수립(plan mode) → 이슈 또는 `docs/`에 저장 → 구현 → 작은 커밋 → 필요 시 ADR / LEARNING.md 업데이트

---

## 12. 코딩 규칙

- Rails 관례(Convention over Configuration)를 따른다.
- 외부 API 연동 로직은 서비스 객체(`app/services/`)로 분리한다. (예: `Transcription::Client`, `Feedback::Analyzer`)
- 통계 계산 로직은 순수 Ruby 클래스로 만들고 단위 테스트를 작성한다.
- 비밀값은 Rails credentials 또는 환경 변수로 관리하고 절대 커밋하지 않는다.
- 변수명/메서드명, 커밋 메시지, 레포 안의 README와 문서는 **영어**로 작성한다.
