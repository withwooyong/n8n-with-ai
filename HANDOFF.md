# Session Handoff

> Last updated: 2026-04-21 (KST, Session 2 종료)
> Repository: git repo (main)
> Latest artifact: `workflow-ver1.json` (n8n workflow ID `5CmV0koXuemjbEmB`, active, v2 via REST PUT)

## Current Status

SOP.md 기반 "고객 문의 자동 응대 시스템" 전 플로우 **End-to-End 검증 완료**. AI provider 는 **OpenAI gpt-4o-mini** (Responses API). 테스트 자동화를 위한 **헬퍼 n8n 워크플로우** 와 bash 스크립트 추가. 현재 `active: true` 로 운영 가능 상태.

## Workflow Registry (n8n instance)

| 워크플로우 이름 | ID | 목적 | 상태 |
|---|---|---|---|
| 고객 문의 자동 응대 시스템 | `5CmV0koXuemjbEmB` | 메인 워크플로우 (12 노드) | ✅ Active |
| 테스트 문의 추가 헬퍼 | `91O4quTAcVPxwkJy` | 테스트용 행 추가 (2 노드) | ✅ Active |

## Completed This Session (Session 2)

| # | 작업 | Artifact |
|---|------|----------|
| 1 | AI provider Gemini → OpenAI 교체 (3 노드 타입 변경, operation `response`, responses API) | workflow v2 |
| 2 | OpenAI credential 등록 (`x0qPkWeqdiwXaKLL` / `openAiApi`) | n8n credential |
| 3 | 응답 경로 수정 `$json.mergedResponse` → `$json.output[0].content[0].text` | — |
| 4 | Alert Error Slack 메시지 포맷 현실화 (문자열 error 필드 대응) | workflow |
| 5 | Parse Classification Code 다중 아이템 처리 (`$input.all().map(...)`) | workflow |
| 6 | 입력 컬럼명 통일 (`접수일시`/`이메일`/`문의내용`) — SOP + workflow 양방 동기화 | SOP.md v1.1 |
| 7 | Retry 정책 상향 (`waitBetweenTries: 2000` → `5000`) | workflow |
| 8 | `scripts/add-test.sh` + 헬퍼 워크플로우 생성 | scripts/, `91O4quTAcVPxwkJy` |
| 9 | SOP.md / CHANGELOG.md / HANDOFF.md / .env.example 업데이트 | docs |
| 10 | End-to-End 검증 (단순문의 2건 + 확인필요 2건 성공) | executions #19, #22, #25, #27 |

## Credential Registry (n8n instance)

| 이름 | Type | ID | 연결 노드 | 상태 |
|---|---|---|---|---|
| **OpenAI account** | `openAiApi` | `x0qPkWeqdiwXaKLL` | Classify Inquiry, Generate Auto Reply, Generate Draft Reply | ✅ 현재 운영용 |
| Gemini API | `googlePalmApi` | `1SWjnYZD2osYmWCX` | (미연결) | ⚠️ 참조용 보존 |
| Slack Bot | `slackApi` | `nWkbliwEwa2orN2y` | Notify Customer Support, Alert Error Slack | ✅ |
| Google Sheets Trigger OAuth2 | `googleSheetsTriggerOAuth2Api` | `9O9wo8ubfWm2tcSf` | On New Inquiry Row | ✅ |
| Google Sheets OAuth2 | `googleSheetsOAuth2Api` | `wrbTh75DInsom76L` | Log Auto Sent, Log Manual Review, 헬퍼 Append Test Row | ✅ |
| Gmail OAuth2 | `gmailOAuth2` | `WDbXULY6iGZrmty6` | Send Customer Email, Create Gmail Draft | ✅ |

## End-to-End Verified Scenarios

| 플로우 | Execution | 고객 | 결과 |
|---|---|---|---|
| 단순문의 → 자동발송 | #22 | 김철수 (배송문의) | Gmail SENT + 로그시트 자동발송 행 |
| 단순문의 → 자동발송 | #27 | 박민수 (제품문의) | Gmail SENT + 로그시트 자동발송 행 |
| 확인필요 → 수동검토 | #19 | 정하나 (환불요청) | Gmail Draft + `#customer-support` Slack + 로그시트 수동확인 행 |
| 확인필요 → 수동검토 | #25 | 정하나 (환불요청, 재현성 확인) | 동일 |
| 에러 경로 → #error-alert | Gemini 503 상황 (이전 세션) | — | #error-alert 메시지 도착 + 포맷 2회 교정 완료 |

## How To Use (운영 관점)

### 테스트 행 추가 (개발 중)
```bash
./scripts/add-test.sh simple      # 김철수 배송 문의
./scripts/add-test.sh product     # 박민수 제품 스펙
./scripts/add-test.sh manual      # 이수진 교환 요청
./scripts/add-test.sh refund      # 정하나 환불 요청
./scripts/add-test.sh custom "홍길동" "a@b.com" "문의 텍스트"
```

### 실제 운영
- Google Forms → Sheet `고객문의_폼` 연결 (Forms 응답이 자동 append)
- n8n Sheet Trigger 가 1분마다 폴링 → 자동 처리
- 담당자는 Gmail 초안 검토 + Slack 알림 확인

## Key Decisions / Gotchas

### AI Provider 선택
- **Gemini 무료 등급 포기 이유**: 분당 15 RPM 초과 시 429, 일일 200 RPD 한도. 동시에 503 Service Unavailable 도 자주 발생 (유료 대비 우선순위 낮음)
- **OpenAI gpt-4o-mini 선택 이유**: 저렴 ($0.15/1M input, $0.60/1M output), Responses API 지원, Rate limit 관대 (유료 티어는 사실상 무제한)
- 월 비용 예상: 본 워크플로우 사용량 기준 **< $1**

### OpenAI Responses API vs Chat Completions
- 사용 operation: `response` (Responses API, n8n typeVersion 2.1)
- 응답 경로: `$json.output[0].content[0].text` (simplify=true 옵션과 무관하게 이 경로)
- messages 대신 `responses.values[]` + 각 값에 `type: "text"` 필드 필요

### Sheets Trigger 동작 특성
- 1분 폴링 (`pollTimes.mode: everyMinute`)
- `staticData.lastIndexChecked` 로 row index 추적
- **1초 이내 연속 append 시 일부 누락 가능** — 헬퍼 스크립트 빠른 연속 호출 시만 발생. 운영에서는 Forms 제출 속도라 무관

### Slack OAuth Scope 재설치
- scope 추가만으로는 기존 토큰에 반영 안 됨
- "Reinstall to Workspace" 로 **새 토큰 발급** 필수 → n8n credential 업데이트

### Alert Error Slack 표현식
- `$json.error` 는 **문자열** 이지 객체 아님 — `.node.name`, `.message` 접근 금지
- 안전한 fallback 체인 필수

### Auto-sanitization 이슈
- `n8n_update_partial_workflow` 의 `updateNode` 호출 시 다른 노드 필드(columns.value 등)가 strip 되는 경우 발생 경험
- 최종 해결: REST API `PUT /api/v1/workflows/{id}` 로 전체 치환하는 방식이 가장 안정적 (이번 세션에서 4회 사용)

## Known Issues (Not Blocking)

1. **Validator warning 11건** — 모두 이전부터 있던 false positive 또는 best practice 제안 (onError 추가 등). 실동작 영향 없음
2. **Switch fallback 3번째 포트 미연결** — `기타` 복잡도 케이스가 나올 때 처리 경로 없음. 현 프롬프트에서는 `단순문의/확인필요` 만 반환하도록 강제하므로 실질 문제 없음
3. **`Parse Classification` Code 노드 `Invalid $ usage detected` warning** — `$input.all()` 사용 시 validator 가 잘못 플래그. 실동작 정상

## Context for Next Session

### 이어서 가능한 작업
1. **에러 경로 강제 테스트** — `Classify Inquiry` 모델명을 일시 `gpt-invalid-model` 로 변경 → #error-alert 동작 재확인
2. **Google Forms 실제 연결** — `고객문의_폼` 시트를 Forms 응답 시트로 설정 (현재는 수동/헬퍼 append)
3. **Switch fallback 연결** — 기타 복잡도 케이스를 `확인필요` 와 합치거나 별도 경로로
4. **운영 품질 개선** — Code 노드 onError 추가, Sheets 노드 onError 추가, valueInputMode 명시 등 validator 제안 반영
5. **비용 모니터링 대시보드** — OpenAI 사용량 주간 리포트 자동화

### 바로 할 수 없는 것 (외부 작업 필요)
- Google Cloud Console 에서 프로덕션용 OAuth 승인 (현재는 테스트 모드)
- Slack App Marketplace 등재 (Bot Token Scopes 안정화 필요 시)

## Files Modified This Session

| 파일 | 변경 유형 |
|---|---|
| `workflow-ver1.json` | 여러 차례 수정 (Gemini → OpenAI 전환, 응답 경로, retry 정책, Parse Classification 코드, Alert 표현식, 컬럼명 통일) |
| `SOP.md` | §3.2/§3.4/§3.5/§5.1/§5.2/§6/§7/§8 업데이트 |
| `CHANGELOG.md` | Session 2 섹션 추가 |
| `HANDOFF.md` | 전면 재작성 (현재 파일) |
| `.env.example` | `OPENAI_API_KEY` 추가, Slack scope 재설치 주의, curl 스니펫 교체 |
| `scripts/add-test.sh` | 신규 생성 |

## Security Notes

- `.env` 에 실제 API 키 6종 저장 (N8N, Gemini, OpenAI, Google OAuth Client, Slack Bot, OPENAI_API_KEY). `.gitignore` 로 추적 제외됨
- n8n credential store 에 동일 값 저장됨 (Docker volume `n8n_data`)
- 대화 중 API 키가 system-reminder 로 1회 노출됐음 (Slack, OpenAI) — 우려 시 재발급 권장
