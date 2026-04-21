# Session Handoff

> Last updated: 2026-04-21 18:46 (KST, Session 2 최종 정리)
> Branch: `main` (tracking `origin/main`)
> Remote: `https://github.com/withwooyong/n8n-with-ai` (public)
> Latest commit: `0deabb0` — README.md, ADR.md 추가

## Current Status

SOP 기반 **"고객 문의 자동 응대 시스템"** 전 기능 구현 + End-to-End 검증 + 공개 저장소 게시까지 완료.
- n8n 워크플로우: `5CmV0koXuemjbEmB` (메인) + `91O4quTAcVPxwkJy` (헬퍼) 모두 `active=true`
- AI provider: **OpenAI gpt-4o-mini** (Responses API)
- Docker 컨테이너는 이번 세션 마지막에 **내림** (`docker compose down`) — volumes 보존됨, `docker compose up -d` 로 언제든 복원
- 저장소: GitHub 에 public 으로 push 완료

## Completed This Session (Session 2 전체)

| # | 작업 | Commit | 비고 |
|---|------|--------|------|
| 1 | AI provider Gemini → OpenAI 교체 | `d23f8a4` | 3 노드 타입/operation/응답 경로 변경 |
| 2 | OpenAI credential 등록 (`x0qPkWeqdiwXaKLL`) | (n8n 내부) | `openAiApi`, 이름 `OpenAI account` |
| 3 | 응답 경로 수정 `$json.mergedResponse` → `$json.output[0].content[0].text` | `d23f8a4` | Responses API 스펙 |
| 4 | Alert Error Slack 표현식 현실화 | `d23f8a4` | `$json.error` 문자열 fallback 체인 |
| 5 | Parse Classification 다중 아이템 처리 | `d23f8a4` | `$input.all().map(...)` |
| 6 | 입력 컬럼명 통일 (`접수일시`/`이메일`/`문의내용`) | `d23f8a4` | SOP + workflow 양방 동기화 |
| 7 | Retry 정책 상향 (wait 2000 → 5000ms) | `d23f8a4` | SOP §5.1 현실화 |
| 8 | `scripts/add-test.sh` + 헬퍼 워크플로우 생성 | `d23f8a4` | 4 프리셋 + custom |
| 9 | SOP/CHANGELOG/HANDOFF/.env.example 업데이트 | `d23f8a4` | v1.3 까지 변경 이력 |
| 10 | End-to-End 검증 (자동발송 2건 + 수동검토 2건) | — | executions #19, #22, #25, #27 모두 success |
| 11 | README.md, ADR.md 신규 작성 | `0deabb0` | 프로젝트 개요 + 결정 기록 10건 |
| 12 | GitHub public repo 생성 + push | `b57a774`~`0deabb0` | `https://github.com/withwooyong/n8n-with-ai` |
| 13 | Slack placeholder 보안 이슈 해결 | `git filter-branch` | history 재작성 후 재푸시 |
| 14 | `.claude/settings.local.json` 생성 | untracked | `includeCoAuthoredBy: true` |
| 15 | Docker 컨테이너 종료 | — | volume 보존, 재기동 가능 |

## In Progress / Pending

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1 | 에러 경로(`#error-alert`) 강제 테스트 | pending | Gemini 시절 자연 발생 503 으로 간접 검증됨. 재확인 시 `Classify Inquiry` 모델명을 `gpt-invalid-model` 로 일시 변경 → 원복 |
| 2 | Google Forms 실제 연결 | pending | 현재는 헬퍼 스크립트/수동 append. Forms 응답 시트를 `고객문의_폼` 으로 지정 필요 (+ `타임스탬프` 컬럼명 rename) |
| 3 | Switch fallback(3번째 포트) 정책 결정 | pending | 현재 미연결. 프롬프트가 `단순문의/확인필요` 만 강제하므로 실질 문제 없음 |
| 4 | validator warning 11건 해소 | pending | false positive + best practice 제안. 실동작 영향 없음 |
| 5 | `.claude/settings.local.json` 커밋 여부 결정 | uncommitted | 공유 원하면 그대로 커밋, 개인용이면 `.gitignore` 에 추가 |

## Key Decisions Made

상세는 `ADR.md` 참조. 핵심 요약:

- **ADR-001** SOP = Single Source of Truth (변경 전파 방향: SOP → workflow.json → n8n 인스턴스)
- **ADR-003** Gemini → OpenAI 교체 (무료 등급 503/429 빈발 → 유료 gpt-4o-mini 월 $1 미만)
- **ADR-004** Retry 5s × 3회 표준 (503 대부분 커버, 429 쿼터 낭비 최소화)
- **ADR-006** Alert Error Slack 표현식은 `$json.error` 문자열 전제 (fallback 체인)
- **ADR-010** 큰 폭 변경은 REST PUT 전체 치환 (auto-sanitization 부작용 회피)

## Known Issues (Not Blocking)

1. **Sheets Trigger race** — 1초 이내 연속 row append 시 일부 누락 가능. 실제 Forms 제출 속도에서는 무관
2. **Validator warning 11건** — 대부분 false positive 또는 best practice 제안. 실동작 정상
3. **`Invalid $ usage detected` (Parse Classification)** — `$input.all()` 을 validator 가 오탐. 실동작 정상
4. **Switch fallback 3번째 포트 미연결** — 현 프롬프트에서 도달 불가하므로 실질 영향 없음

## Context for Next Session

### 사용자의 원래 의도 + 현재 상태
SOP.md 기반 워크플로우를 n8n 에 **즉시 운영 가능한 수준** 으로 구축 + 공개 저장소로 게시. 본 세션에서 이 목표는 달성됨.

### 결정된 주요 방향
- AI provider: **OpenAI `gpt-4o-mini`** (Responses API). Gemini 대체
- 테스트 자동화: **헬퍼 n8n 워크플로우 + bash 스크립트** (외부 언어 의존 없음)
- 문서 정책: SOP = SSoT, 변경 시 ADR 작성, 세션 단위 CHANGELOG / HANDOFF

### 제약/사용자 선호
- 커밋 메시지 한글 (글로벌 CLAUDE.md)
- `git push` 는 명시 요청 시만 (글로벌 CLAUDE.md)
- `.env`, `.mcp.json` 커밋 금지 (프로젝트 CLAUDE.md)
- 노드 이름은 **영어** (프로젝트 CLAUDE.md)
- AI/외부 API 노드는 **Retry On Fail + On Error 분기** 필수 (프로젝트 CLAUDE.md)

### 다음 세션에서 바로 할 수 있는 것
1. Docker 컨테이너 재기동: `docker compose up -d` → 워크플로우 자동 Active
2. 에러 경로 강제 테스트 (위 Pending #1)
3. Google Forms 연결 (위 Pending #2)
4. validator warning 정리 (위 Pending #4)

### 바로 할 수 없는 것
- Google Cloud OAuth consent screen 프로덕션 승인 (Google 심사 과정)
- Slack App Marketplace 공개 (n8n 로컬 전용이라 불필요)

## Files Modified This Session (git diff vs 세션 시작 전)

| 파일 | 변경 유형 | 커밋 |
|---|---|---|
| `workflow-ver1.json` | 대규모 수정 (전환 + path + retry + 다중아이템 + 컬럼명) | `d23f8a4` |
| `SOP.md` | §3/§5/§6/§7/§8 현행화 | `d23f8a4` |
| `CHANGELOG.md` | Session 2 섹션 추가 (본 /handoff 로 보완) | `d23f8a4`, (현재) |
| `HANDOFF.md` | 전면 재작성 (본 파일) | `d23f8a4`, (현재) |
| `.env.example` | `OPENAI_API_KEY` 추가, Slack placeholder 형식 변경 | `d23f8a4`, history rewrite |
| `scripts/add-test.sh` | 신규 | `d23f8a4` |
| `README.md` | 신규 | `0deabb0` |
| `ADR.md` | 신규 | `0deabb0` |
| `.claude/settings.local.json` | 신규 (`includeCoAuthoredBy: true`) | **uncommitted** |

## Security Notes

- `.env` 에 실제 API 키 6종 저장 (N8N API / OpenAI / Gemini / Google OAuth Client / Slack Bot). `.gitignore` 로 추적 제외
- n8n credential store 는 Docker named volume `n8n_data` 에 암호화 저장됨 (`docker compose down` 으로 컨테이너 제거해도 보존)
- 대화 중 API 키가 system-reminder 로 1회 노출됨 (Slack Bot, OpenAI API Key) — 우려 시 재발급 권장
- GitHub push 시 Slack 토큰 placeholder 오탐 → history rewrite 로 해결. **실키 노출 없음**

## Uncommitted Work

- `.claude/settings.local.json` (untracked) — `includeCoAuthoredBy: true`
  - 커밋 여부 결정 필요 (팀 공유 / 개인용)
