# Session Handoff

> Last updated: 2026-04-21 (KST)
> Repository: not a git repo
> Latest artifact: `workflow-ver1.json` (n8n workflow ID `5CmV0koXuemjbEmB`)

## Current Status

SOP.md 기반 "고객 문의 자동 응대 시스템" n8n 워크플로우가 로컬 n8n 인스턴스(http://localhost:5678)에 생성되어 있고, 12개 노드 전부 credential이 연결된 상태. Validation PASS (errors: 0). **활성화 직전** — 남은 건 사용자가 n8n UI에서 처리해야 할 OAuth 동의 플로우와 외부 리소스 세팅(시트 헤더, Slack 채널 초대).

## Completed This Session

| # | Task | Artifact | Files |
|---|------|----------|-------|
| 1 | SOP.md 파싱 → 12 노드 워크플로우 설계 (Trigger/Gemini×3/Code/Switch/Gmail×2/Sheets×2/Slack×2) | n8n workflow `5CmV0koXuemjbEmB` | — |
| 2 | 워크플로우 로컬 export | `workflow-ver1.json` 생성 | `workflow-ver1.json` |
| 3 | Credential 등록 템플릿 작성 | `.env.example` 확장 | `.env.example` |
| 4 | `.env` 의 Google OAuth Client ID 오타 수정 (`.comcom` → `.com`) | — | `.env` |
| 5 | n8n credential 5개 등록 (Gemini, Slack, Sheets Trigger OAuth2, Sheets OAuth2, Gmail OAuth2) | n8n credentials 5건 | — |
| 6 | 12개 노드에 credential 연결 + Sheet ID 3곳 치환 | — | — |
| 7 | Auto-sanitization으로 날아간 필드 2회 복원 (resource/operation/columns) | — | — |
| 8 | Validation PASS (errors: 0) | — | — |

## Credential Registry (n8n instance)

| 이름 | Type | ID | 연결 노드 | 상태 |
|---|---|---|---|---|
| Gemini API | `googlePalmApi` | `1SWjnYZD2osYmWCX` | Classify Inquiry, Generate Auto Reply, Generate Draft Reply | ✅ 바로 사용 가능 |
| Slack Bot | `slackApi` | `nWkbliwEwa2orN2y` | Notify Customer Support, Alert Error Slack | ✅ 바로 사용 가능 |
| Google Sheets Trigger OAuth2 | `googleSheetsTriggerOAuth2Api` | `9O9wo8ubfWm2tcSf` | On New Inquiry Row | ⚠️ OAuth 동의 필요 |
| Google Sheets OAuth2 | `googleSheetsOAuth2Api` | `wrbTh75DInsom76L` | Log Auto Sent, Log Manual Review | ⚠️ OAuth 동의 필요 |
| Gmail OAuth2 | `gmailOAuth2` | `WDbXULY6iGZrmty6` | Send Customer Email, Create Gmail Draft | ⚠️ OAuth 동의 필요 |

## In Progress / Pending

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1 | Google OAuth2 3종 동의 플로우 | **pending (UI 필수)** | n8n Credentials 화면에서 "Sign in with Google" 버튼 클릭 — API로 자동화 불가 |
| 2 | Google Cloud Console 설정 | pending | Sheets API + Gmail API Enable, OAuth consent screen의 Test users에 본인 Google 계정 추가 |
| 3 | 스프레드시트 2개 시트 생성 | pending | 문서 ID `1V6cIC3_5s3w6xq-ZjVZnEQ65rXXbTY56UwxNcoACFUQ` 에 `고객문의_폼`(타임스탬프·고객명·이메일 주소·문의 내용) / `고객문의_로그`(접수일시·고객명·이메일·문의내용·카테고리·복잡도·처리방식) |
| 4 | Slack 봇 초대 | pending | `#customer-support`, `#error-alert` 두 채널에 `/invite @봇이름` |
| 5 | Sheets 노드 시트명 select | pending | 각 노드의 Sheet 드롭다운에서 실제 시트 선택 (`value` 비어있음, `cachedResultName` 만 존재) |
| 6 | End-to-end 테스트 | pending | 단순문의/확인필요 각 1건 입력 → 1분 내 실행 확인 후 Active 토글 |

## Key Decisions Made

- **워크플로우 구조**: Gemini 분류 결과는 JSON으로 요청 → `Parse Classification` Code 노드에서 방어적 파싱(markdown fence 제거, 실패 시 `{category:'기타', complexity:'확인필요'}` fallback)으로 처리. Switch 는 rules 모드 + caseSensitive strict 로 `단순문의`/`확인필요` 분기.
- **에러 핸들링**: SOP §5.1 대로 3개 Gemini 노드에 `retryOnFail: true, maxTries: 3, waitBetweenTries: 2000`. 재시도 실패 시 `onError: continueErrorOutput` 의 두 번째 출력 → 단일 `Alert Error Slack` 에 수렴 (#error-alert).
- **Google OAuth 분리**: `googleSheetsTriggerOAuth2Api` / `googleSheetsOAuth2Api` / `gmailOAuth2` 는 별도 credential type 이라 **3개를 각각 등록** (같은 Client ID/Secret 재사용). n8n이 type 별로 토큰을 따로 관리하므로 "Sign in with Google" 도 3번 필요.
- **Sheet ID 주입 방식**: `documentId` 를 `mode: "id"` 로 하드코딩. `sheetName` 은 `mode: "list"` + `cachedResultName` 만 채우고 `value` 는 UI에서 직접 선택하도록 비워둠 (Sheet 내부의 sheet gid 가 UI 드롭다운 선택으로 제대로 들어감).

## Known Issues

- **Validator false positive**: `Route by Complexity` 의 `main[1]` 출력(확인필요 분기)에 대해 "missing onError: continueErrorOutput" 경고가 나오지만, Switch 는 본래 다분기 노드이므로 `main[1]` 은 에러 출력이 아님. 실제 동작에 영향 없음.
- **Auto-sanitization 재발 위험**: n8n-mcp 의 `n8n_update_partial_workflow` 호출 시 모든 노드에 sanitization 이 재실행되어 기본값으로 간주된 필드(`resource`, `operation`, `emailType`, `columns`)가 strip 되는 현상을 이번 세션에서 2회 겪음. 다음 세션에서 partial update 를 또 할 경우 최종 validation 을 반드시 돌려 확인할 것.
- **Gemini 출력 필드명 불확실**: `includeMergedResponse: true` 설정 시 출력 필드가 `content` 인지 `text` 인지 소스에서 확정하지 못함. `Parse Classification` 은 방어적이라 OK 이지만 `Send Customer Email` / `Create Gmail Draft` 의 `message: "={{ $json.content }}"` 는 실제 실행 시 비어있으면 `{{ $json.text }}` 등으로 교정 필요.
- **Slack 채널 mode**: 2개 Slack 노드 모두 `channelId.mode: "name"` + `value: "#customer-support"` / `"#error-alert"` 로 하드코딩. n8n Slack 노드가 channel name 모드를 지원하는지 실제 실행에서 검증 필요 (id 모드로의 fallback 필요 가능).
- **Switch fallback 경로**: `fallbackOutput: "extra"` 로 설정되어 있어 `단순문의`/`확인필요` 어느 값도 아닌 경우의 3번째 출력이 미연결 상태 (+). 정책상 `기타` 복잡도가 들어올 수 있는지 사용자 결정 필요.

## Context for Next Session

### 사용자의 원래 의도
`SOP.md` 에 정의된 "고객 문의 자동 응대 시스템" 을 n8n 로컬 인스턴스에 **그대로 구현** + **활성화 전 credential 자동화 최대화**. n8n skill + n8n-mcp 도구를 적극 활용할 것.

### 선택한 접근
1. 한 번에 12 노드 전부를 `n8n_create_workflow` 로 생성 (iterative 빌드 대신 일괄 생성)
2. Validation driven — error 없을 때까지 `n8n_update_partial_workflow` 로 교정
3. Credential 은 API 로 자동 등록 가능한 것(apiKey/token 기반)부터 먼저 처리, OAuth2 는 Client ID/Secret 까지만 등록하고 동의 플로우는 사용자 UI 로 위임

### 제약/사용자 선호
- 커밋 메시지 한글 (글로벌 CLAUDE.md) — 이 프로젝트는 git repo가 아니라 미적용
- `git push` 는 명시적 요청 시만 (글로벌 CLAUDE.md)
- `.env` / `.mcp.json` 커밋 금지 (CLAUDE.md)
- 노드 이름은 **영어** (CLAUDE.md) — 준수
- AI/외부 API 호출 노드는 **Retry On Fail + On Error 분기** 필수 (CLAUDE.md) — Gemini 3개, Gmail 2개, Slack 2개에 적용

### 다음 세션에서 바로 할 수 있는 것
1. 사용자가 "OAuth 동의 끝났다" 하면 → `n8n_executions` 로 최근 실행 확인 또는 `n8n_test_workflow` 호출
2. Gemini 출력 필드명 실제 확인 후 expression 교정 (`Send Customer Email`, `Create Gmail Draft` 의 `message`)
3. Switch fallback 경로 정책 결정 후 연결 또는 제거
4. 활성화 (`n8n_update_partial_workflow` with `activateWorkflow` operation)

## Files Modified This Session

| 파일 | 변경 유형 |
|---|---|
| `workflow-ver1.json` | 신규 (12 노드 워크플로우 JSON) |
| `.env.example` | 확장 (credential 템플릿 5종 추가) |
| `.env` | 사용자 입력 + OAuth Client ID 오타 수정 (`.comcom` → `.com`) |
| `CHANGELOG.md` | 신규 (이번 handoff) |
| `HANDOFF.md` | 신규 (이번 handoff) |

## Security Notes

- `.env` 에 실제 API 키 5종 (n8n API Key, Gemini API Key, Slack Bot Token, Google OAuth Client ID/Secret) 저장 상태. git 추적 안 됨 (프로젝트 자체가 git repo 아님).
- n8n 인스턴스의 credential store 에 동일 값이 저장됨 (Docker volume `n8n_data`).
- 세션 전체에서 비밀값은 대화 컨텍스트 이외로 유출되지 않았지만, 우발적 공유 위험 있었으면 **Gemini API Key / Slack Bot Token 재발급** 권장.
