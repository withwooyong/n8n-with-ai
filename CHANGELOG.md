# Changelog

All notable changes to this project are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/).

## [Unreleased]

### Added
- (new features)

### Changed
- (modifications to existing features)

### Fixed
- (bug fixes)

### Removed
- (removed features)

---

## [2026-04-21 afternoon] Session 2 — OpenAI 마이그레이션 + 헬퍼 워크플로우 + GitHub 게시

### Added
- **헬퍼 n8n 워크플로우** "테스트 문의 추가 헬퍼" (ID: `91O4quTAcVPxwkJy`, active=true) — Webhook 트리거(POST `/webhook/test-inquiry`) → Google Sheets Append. Main workflow 의 Sheets 트리거를 자연스럽게 발동시키는 테스트 보조
- **`scripts/add-test.sh`** — 프리셋 4종(simple/product/manual/refund) + custom 모드. 한 줄로 테스트 문의 생성 → E2E 검증 속도 개선
- **OpenAI credential** 등록 (`x0qPkWeqdiwXaKLL`, `openAiApi` 타입, 이름 `OpenAI account`) — 기존 Gemini API credential 은 참조용으로 보존
- `scripts/` 디렉터리 신규
- **`README.md`** 신규 — 프로젝트 개요, 파일 구조, prerequisites, 빠른 시작 6단계, 워크플로우 흐름 다이어그램, 테스트 헬퍼 사용법, 문서 인덱스 (commit `0deabb0`)
- **`ADR.md`** 신규 — 10건의 주요 기술 결정 기록 (MADR 간소화, SOP SSoT / AI provider / retry 정책 / 에러 처리 / 컬럼명 통일 / 테스트 헬퍼 / 다중 아이템 처리 / REST PUT 전략 등) (commit `0deabb0`)
- **GitHub public repo 게시** — `https://github.com/withwooyong/n8n-with-ai` (main 브랜치 tracking origin)
- `.claude/settings.local.json` — `includeCoAuthoredBy: true` 설정 (Claude Code 커밋 작성자 태그 활성화)

### Changed
- **AI Provider: Google Gemini → OpenAI** — 3개 노드 (Classify Inquiry / Generate Auto Reply / Generate Draft Reply) 전부 교체
  - node type: `@n8n/n8n-nodes-langchain.googleGemini` (v1.1) → `@n8n/n8n-nodes-langchain.openAi` (v2.1)
  - 모델: `gemini-2.5-flash` → `gemini-2.0-flash` → 최종 **`gpt-4o-mini`**
  - operation: `message` → **`response`** (OpenAI Responses API)
  - 프롬프트 구조: `options.systemMessage` + `messages.values[0]` → `responses.values[]` (system + user)
  - 전환 이유: Gemini 무료 등급의 연속 503 (Service Unavailable) + 429 (Rate Limit) 빈발로 안정성 확보 어려움
- **Gemini retry 정책 변경** (이후 OpenAI 로 이전되어 동일 정책 유지): maxTries 3 → 5 → 3 (최종), waitBetweenTries 2000 → 5000ms — SOP §5.1 현실화
- **응답 경로 표현식 교정**: `$json.mergedResponse` → `$json.output[0].content[0].text` (Responses API 스펙)
- **Alert Error Slack 메시지 포맷 교정**: `$json.error` 가 **문자열** 이므로 `.node.name`, `.message` 객체 접근 제거 → fallback 체인으로 변경
- **입력 컬럼명 통일**: `타임스탬프`/`이메일 주소`/`문의 내용` → `접수일시`/`이메일`/`문의내용` (로그 시트 컨벤션 따름)
- **`Parse Classification` Code 노드** 다중 아이템 처리 지원 (`$input.first()` → `$input.all().map(...)`)
- **SOP.md** §3.2/§3.4.1/§5.1/§6/§7/§8 — OpenAI 전환 반영, 재시도 5s, 변경 이력 v1.1~v1.3 추가
- **`.env.example`** — `OPENAI_API_KEY` 신규 항목 + Slack scope 재설치 주의 문구 + OpenAI curl 스니펫

### Fixed
- Gmail `Send Customer Email` / `Create Gmail Draft` 의 `.trim() is not a function` — 응답 구조 오해로 인한 undefined 참조 해결
- Slack "missing scope `chat:write:bot`" 에러 — `chat:write` scope 추가 + **Reinstall to Workspace** 로 토큰 재발급 후 n8n credential 업데이트
- Gmail "Invalid email address" — 시트 행 빈 셀 입력 시 trigger 가 즉시 발화하는 현상. 해결책은 4셀 동시 복붙 권장 (헬퍼 스크립트가 해결)
- Sheets Trigger `sheetName.value` 가 REST PUT 시 strip 되는 auto-sanitization 현상 — 최종 상태는 `cachedResultName` 에 의존
- Switch fallback 출력 3번째 포트 연결 안 됨 (기타 복잡도 케이스) — 현재도 유지, 정책 결정 유보

### Known Issues
- **Sheets Trigger race**: 1초 이내 연속 row append 시 일부 행 누락 가능. 실제 Forms 제출은 사람 속도라 운영 영향 없음. 헬퍼 스크립트 연속 호출 시에만 체감
- **validator warnings 11건** 은 false positive 또는 best-practice 제안 (onError 추가 등). 실동작 영향 없음

### Removed
- Gemini 기반 `mergedResponse` 표현식 (모든 expression 교체됨)

### Security
- **Slack 토큰 placeholder 재작성** — `.env.example` 의 Slack 토큰 자리값이 **Slack 토큰 형식 정규식** 과 일치해 GitHub secret scanner 가 실토큰으로 오탐. 형식과 무관한 문자열(`xoxb-REPLACE-WITH-YOUR-BOT-USER-OAUTH-TOKEN`)로 교체 + `git filter-branch` 로 **3개 전 커밋 history 소급 재작성** 후 푸시 성공. 실제 비밀값은 `.env` (gitignore) 에만 존재, 노출 사고 아님

---

## [2026-04-21 morning] Session 1 — 초기 구축

### Added
- `workflow-ver1.json` — SOP.md 기반 "고객 문의 자동 응대 시스템" 12 노드 워크플로우 JSON export 생성
- n8n 워크플로우 인스턴스 생성 (ID: `5CmV0koXuemjbEmB`) — Google Sheets Trigger → Gemini 분류 → Switch 분기 → 자동 발송 / 수동 초안 / Slack 알림 / Sheets 로깅 + Gemini 실패 시 #error-alert 집약
- `.env.example` 에 credential 템플릿 추가 — Google Sheets Document ID, OAuth Client ID/Secret, Gemini API Key, Slack Bot Token + 사용 방법 주석
- n8n credential 5개 등록 — `Gemini API`, `Slack Bot`, `Google Sheets Trigger OAuth2`, `Google Sheets OAuth2`, `Gmail OAuth2`
- 12개 노드에 credential 연결 완료 (3 Gemini + 2 Slack + 1 Sheets Trigger + 2 Sheets Log + 2 Gmail + 2 Code/Switch)

### Changed
- `On New Inquiry Row` / `Log Auto Sent` / `Log Manual Review` 의 `documentId` 를 placeholder(`YOUR_SHEET_ID`) → 실제 Sheet ID(`1V6cIC3_5s3w6xq-ZjVZnEQ65rXXbTY56UwxNcoACFUQ`)로 치환
- Gemini 3개 노드에 Retry On Fail (3회, 2s 대기) + `onError: continueErrorOutput` 적용 — SOP §5.1 준수

### Fixed
- Google Sheets Trigger 의 `sheetName.mode` 값을 지원되지 않는 `name` → `list` 로 수정 (validator error 해소)
- `Alert Error Slack` 표현식의 옵셔널 체이닝(`?.`) 제거 — n8n 표현식 미지원 경고 해소
- `.env` 의 `GOOGLE_OAUTH_CLIENT_ID` 끝 오타(`.comcom` → `.com`) 수정
- Auto-sanitization 으로 Gmail/Sheets/Slack 노드의 `resource`/`operation`/`columns` 필드가 2회 stripping 된 것을 재주입 복원
