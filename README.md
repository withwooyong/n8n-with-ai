# n8n 고객 문의 자동 응대 시스템

> Google Forms/Sheets 로 수집된 고객 문의를 **OpenAI gpt-4o-mini** 로 자동 분류한 뒤,
> 단순 문의는 **즉시 자동 답변 발송**, 확인 필요 건은 **담당자 검토용 초안 + Slack 알림** 으로 분기 처리하는 n8n 워크플로우.

- **목적**: 고객 응대 1차 응답 시간 단축 + 품질 관리 병행
- **기반**: n8n (self-hosted) + OpenAI Responses API + Google Sheets / Gmail + Slack
- **핵심 산출물**: [`workflow-ver1.json`](./workflow-ver1.json) (12 노드), [`SOP.md`](./SOP.md), [`scripts/add-test.sh`](./scripts/add-test.sh)

---

## 🗂 파일 구조

```
n8n-with-ai/
├── SOP.md                   # 워크플로우 Source of Truth (로직·프롬프트·에러정책)
├── README.md                # 프로젝트 개요 (이 파일)
├── ADR.md                   # 주요 기술 결정 기록
├── CHANGELOG.md             # 세션별 변경 이력
├── HANDOFF.md               # 세션 종료 인수인계
├── CLAUDE.md                # Claude Code 작업 가이드 (프로젝트 규칙)
├── workflow-ver1.json       # 완성된 n8n 워크플로우 export
├── .env.example             # credential 템플릿 (실키는 .env 에 보관)
├── .mcp.json.example        # n8n-mcp 설정 샘플
├── docker-compose.yml       # 로컬 n8n 컨테이너 정의
└── scripts/
    └── add-test.sh          # 테스트 문의 추가 헬퍼 (4 프리셋 + custom)
```

---

## ⚙️ Prerequisites

- Docker / Docker Compose (로컬 n8n 기동용)
- Google Cloud OAuth Client (Sheets API + Gmail API 활성, Test users 에 본인 계정 추가)
- OpenAI API Key (`gpt-4o-mini` 호출 가능)
- Slack App + Bot Token (`chat:write`, `chat:write.public`, `channels:read` scope)
- Google 스프레드시트 1개 (같은 문서 안에 `고객문의_폼` / `고객문의_로그` 시트 2개)

---

## 🚀 빠른 시작

### 1) 로컬 n8n 기동

```bash
docker-compose up -d
# → http://localhost:5678
```

### 2) Credential 준비

`.env.example` 을 `.env` 로 복사한 뒤 값 채우기:

```bash
cp .env.example .env
# 에디터로 열어서 API 키 입력
```

### 3) n8n Credentials 등록 (UI)

http://localhost:5678 → **Credentials** 메뉴 → 아래 6개 생성:

| 이름 | Type | 용도 |
|---|---|---|
| `OpenAI account` | OpenAI | AI 분류 / 답변 생성 |
| `Slack Bot` | Slack API | 알림 (`#customer-support`, `#error-alert`) |
| `Google Sheets Trigger OAuth2` | Google Sheets Trigger OAuth2 | 트리거 폴링 |
| `Google Sheets OAuth2` | Google Sheets OAuth2 | 로그 append |
| `Gmail OAuth2` | Gmail OAuth2 | 발송 + 초안 |

> OAuth 3종은 Google Cloud Console 에서 Client ID/Secret 을 먼저 발급해야 합니다.
> 자세한 절차는 [`SOP.md §7.1`](./SOP.md) 배포 체크리스트 참고.

### 4) 워크플로우 import

n8n UI → **Workflows** → **Import from File** → `workflow-ver1.json` 선택.

시트 드롭다운 3곳 (On New Inquiry Row / Log Auto Sent / Log Manual Review) 에서 실제 시트 이름 재선택 → **Publish** → **Activate**.

### 5) Slack 봇 초대

```
#customer-support  →  /invite @봇이름
#error-alert       →  /invite @봇이름
```

### 6) 동작 확인

```bash
./scripts/add-test.sh simple   # 김철수 배송 문의
./scripts/add-test.sh manual   # 이수진 교환 요청
```

1분 내 폴링 → n8n **Executions** 탭에서 실행 결과 확인.
- 단순문의 → `withwooyong@gmail.com` 받은편지함
- 확인필요 → Gmail **Drafts** 폴더 + Slack `#customer-support`

---

## 🧠 워크플로우 흐름

```
[Google Sheets Trigger (onRowAdded)]
        │
        ▼
[OpenAI: Classify Inquiry (JSON 분류)]
        │
[Code: Parse Classification (방어적 파싱)]
        │
        ▼
[Switch: Route by Complexity]
        ├─ 단순문의 ──▶ [OpenAI: Generate Auto Reply] ──▶ [Gmail: Send] ──▶ [Sheets: Log 자동발송]
        │
        └─ 확인필요 ──▶ [OpenAI: Generate Draft Reply] ──▶ [Gmail: Create Draft] ──▶ [Slack: #customer-support] ──▶ [Sheets: Log 수동확인]

3개 OpenAI 노드 retry 실패 시 → [Slack: #error-alert]
```

전체 사양은 [`SOP.md`](./SOP.md) 참조.

---

## 🛠 테스트 헬퍼

별도 n8n 워크플로우 **"테스트 문의 추가 헬퍼"** (ID: `91O4quTAcVPxwkJy`) 가 Webhook → Sheet Append 로 구성되어 있어, 시트에 수동 입력 없이 빠르게 테스트 가능.

```bash
./scripts/add-test.sh                # 기본 simple
./scripts/add-test.sh simple         # 배송 문의 (단순문의 예상)
./scripts/add-test.sh product        # 제품 스펙 (단순문의 예상)
./scripts/add-test.sh manual         # 교환 요청 (확인필요 예상)
./scripts/add-test.sh refund         # 환불 요청 (확인필요 예상)
./scripts/add-test.sh custom "이름" "이메일" "문의내용"
```

환경 변수로 커스터마이즈:
```bash
TEST_EMAIL="other@example.com" WEBHOOK_URL="https://n8n.mycompany/webhook/test-inquiry" \
  ./scripts/add-test.sh manual
```

---

## 📚 문서

| 문서 | 용도 |
|---|---|
| [`SOP.md`](./SOP.md) | **진실 공급원** — 트리거, 프롬프트, 라우팅, 로깅, 에러 처리 전 명세 |
| [`ADR.md`](./ADR.md) | 주요 기술 결정 이력 (AI provider 선택, API 전략 등) |
| [`CHANGELOG.md`](./CHANGELOG.md) | 세션별 변경 사항 |
| [`HANDOFF.md`](./HANDOFF.md) | 최신 세션 인수인계 |
| [`CLAUDE.md`](./CLAUDE.md) | Claude Code 작업 가이드 (워크플로우 제작 프로세스) |

---

## 🔐 보안 메모

- `.env`, `.mcp.json` 은 `.gitignore` 로 추적 제외
- OAuth Client Secret / API Key 는 절대 커밋 금지
- n8n credential store 는 Docker volume `n8n_data` 에 암호화 저장됨

---

## 📝 라이선스

학습 목적 개인 프로젝트 (별도 라이선스 미정)
