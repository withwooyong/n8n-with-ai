# Architecture Decision Records

이 문서는 n8n-with-ai 프로젝트에서 내린 **주요 기술 결정** 과 **그 배경** 을 기록한다.
세부 구현이 바뀌더라도 결정의 맥락을 추적할 수 있도록 **왜 그렇게 했는가**를 중점적으로 남긴다.

> 형식: [MADR](https://adr.github.io/madr/) 간소화 버전

---

## ADR-001: SOP 를 진실 공급원(Single Source of Truth)으로 둔다

- **Status**: Accepted (2026-04-21)
- **Context**:
  워크플로우 코드(노드 JSON)는 정교하지만 가독성이 낮고, 의도·정책이 코드에서 유추되기 어렵다.
  프롬프트·분기 규칙·에러 정책이 흩어지면 변경 시 일관성을 유지하기 어렵다.
- **Decision**:
  `SOP.md` 를 **모든 로직·프롬프트·에러 정책의 원천 문서** 로 두고, 변경은 `SOP.md` → `workflow-ver1.json` → n8n 인스턴스 순으로 전파한다. 역방향 변경(워크플로우만 수정)은 금지.
- **Consequences**:
  - 🟢 신규 협업자가 워크플로우 본 이해 없이도 맥락 파악 가능
  - 🟢 변경 이력(§8 변경 이력 테이블)이 문서화됨
  - 🟡 SOP 수정을 깜빡하면 문서-실물 동기화 깨짐 → CHANGELOG/HANDOFF 에서 재확인 루틴 필요

---

## ADR-002: AI 분류를 **구조화된 JSON 출력** 으로 받는다

- **Status**: Accepted (2026-04-21)
- **Context**:
  LLM 이 자유 텍스트로 분류 결과를 반환하면 후처리 파싱이 불안정.
  마크다운 코드펜스(\`\`\`json ... \`\`\`) 를 붙여 반환하는 케이스도 빈번.
- **Decision**:
  1. 시스템 프롬프트에 **엄격한 JSON 출력 형식** 명시 (`category / complexity / reason`)
  2. `Parse Classification` Code 노드에서 **방어적 파싱**:
     - 다양한 응답 구조 (`$json.output[0].content[0].text`, `$json.message.content`, `$json.choices[0].message.content` 등) 를 순서대로 시도
     - markdown fence 제거
     - `JSON.parse` 실패 시 **안전 기본값** (`{category:'기타', complexity:'확인필요'}`) 로 fallback → 무조건 담당자 검토로 회부
- **Consequences**:
  - 🟢 LLM 불안정성에 강건
  - 🟢 운영 중 이상 케이스가 자동 발송으로 빠져나가지 않음 (기본값이 "확인필요")
  - 🟡 LLM 이 틀린 JSON 을 꾸준히 내면 카테고리 분포가 `기타` 로 편향 → 주기적 모니터링 필요

---

## ADR-003: AI Provider 를 **Google Gemini 에서 OpenAI 로 교체**

- **Status**: Accepted (2026-04-21 Session 2)
- **Context**:
  초기 구축 시 Gemini 무료 등급(`gemini-2.5-flash`)을 선택. 학습·테스트 목적이라 과금 최소화 목표.
  그러나 실제 검증 중 다음 문제 반복:
  - 503 Service Unavailable — Google 측 일시 장애 (유료 대비 free tier 우선순위 낮음)
  - 429 Rate Limit — `gemini-2.0-flash` 기준 분당 15 RPM / 일일 200 RPD 초과
  - retry 간격을 늘려도 free tier 는 동시 요청이 몰리면 재발
- **Alternatives**:
  1. Gemini 유료 등급 전환 → 예산 불명확, 학습 단계에서 부담
  2. 재시도 대기 간격 대폭 확대 → 응답 속도 악화
  3. OpenAI `gpt-4o-mini` 로 이전
- **Decision**:
  **OpenAI `gpt-4o-mini` (Responses API)** 로 이전.
  - 비용: $0.15/$0.60 per 1M input/output tokens. 본 워크플로우 사용량 기준 월 $1 미만 예상
  - 안정성: 503/429 빈도 훨씬 낮음 (유료 티어는 사실상 무제한 RPM)
  - 응답 품질: 한국어 고객 응대 메시지 품질이 Gemini 대비 동등 이상
- **Implementation notes**:
  - 노드 타입: `@n8n/n8n-nodes-langchain.googleGemini` (v1.1) → `@n8n/n8n-nodes-langchain.openAi` (v2.1)
  - operation: `response` (Responses API; `message` 는 typeVersion 2.1 에서 invalid)
  - 응답 경로: `$json.mergedResponse` → `$json.output[0].content[0].text`
  - `simplify: true` 로 설정했지만 응답 구조는 동일 (output[] 배열 형태)
- **Consequences**:
  - 🟢 테스트/운영 안정성 향상
  - 🟡 월 소액 과금 발생 (학습용이면 수용 가능)
  - 🟡 Gemini credential 은 참조용으로 보존 (향후 fallback 가능성)

---

## ADR-004: 재시도 간격 **5초 / 3회** 를 표준으로

- **Status**: Accepted (2026-04-21 Session 2)
- **Context**:
  - 초기: `maxTries: 3, waitBetweenTries: 2000ms` (SOP §5.1 최초)
  - 503 다발 시 `maxTries: 5, waitBetweenTries: 5000ms` 로 상향해봤으나, 429 상황에서는 retry 가 많을수록 **쿼터를 더 소모하여 악순환**
- **Decision**:
  **`maxTries: 3, waitBetweenTries: 5000ms`** 로 확정.
  - 503 (일시 장애) 은 수초~수분 내 회복 → 5초 × 3회 = 15초 대기로 대부분 커버
  - 429 (rate limit) 은 RPM 1분 윈도우 → 15초 내 회복 불가 → 어차피 실패 → 재시도 횟수 늘릴 이유 없음
  - 5초 간격은 전체 응답 시간에 큰 부담 없음 (성공 시 0회, 실패 시만 발생)
- **Consequences**:
  - 🟢 503 대부분 복구
  - 🟢 429 시 쿼터 낭비 최소화
  - 🟡 10초 이상 지속 장애는 `onError` 로 이동 → `#error-alert` 로 담당자 개입

---

## ADR-005: 에러 처리는 **노드 레벨 onError + 단일 집약 Slack 알림**

- **Status**: Accepted (2026-04-21)
- **Context**:
  각 AI/Gmail/Slack 노드마다 별도 에러 워크플로우 연결하면 유지보수 부담.
  반면 에러를 무시하면 고객 응대 누락이라는 치명적 장애.
- **Decision**:
  3개 OpenAI 노드에 `onError: "continueErrorOutput"` 설정 → 에러 출력이 단일 `Alert Error Slack` 노드로 수렴.
  - Gmail/Sheets/Slack 노드는 자체 retry 만 두고 `onError` 는 workflow-level 로 넘김 (실패 시 전체 execution 이 error 로 기록)
- **Consequences**:
  - 🟢 운영자가 `#error-alert` 채널 하나만 모니터링하면 충분
  - 🟢 에러 컨텍스트(고객명/문의내용/Execution URL) 를 자동 포함
  - 🟡 Gmail/Sheets 자체 에러는 execution 레벨에서만 보임 → 알림 받으려면 n8n Error Trigger 워크플로우 추가 고려

---

## ADR-006: Alert Error Slack 표현식은 **문자열 error 필드 전제**

- **Status**: Accepted (2026-04-21 Session 2)
- **Context**:
  초기 SOP 는 `{{ $json.error.node.name }}`, `{{ $json.error.message }}` 로 객체 접근을 가정.
  실제 n8n `onError: continueErrorOutput` 경로의 데이터는 `$json.error` **문자열** 이라 객체 접근 시 undefined → "unknown" / "내용 없음" 출력.
- **Decision**:
  fallback 체인으로 변경:
  ```
  {{ $json.error || ($json.error && $json.error.message) || $json.message || '내용 없음' }}
  ```
  더불어 upstream trigger 데이터를 직접 참조하여 고객/이메일/문의내용이 항상 표시되도록:
  ```
  {{ $('On New Inquiry Row').item.json['고객명'] || $json.customerName || 'unknown' }}
  ```
- **Consequences**:
  - 🟢 실제 실패 시 의미 있는 메시지 출력
  - 🟡 표현식이 길어짐 → 가독성 저하 (주석으로 SOP 에서 보완)

---

## ADR-007: 시트 컬럼명을 **폼/로그 시트 간 통일**

- **Status**: Accepted (2026-04-21)
- **Context**:
  초기 SOP 는 Google Forms 기본 용어 `타임스탬프 / 이메일 주소 / 문의 내용` 과 로그시트 업무 용어 `접수일시 / 이메일 / 문의내용` 을 분리 사용.
  매핑 복잡, n8n 표현식 내 공백 포함 키 (`$json["이메일 주소"]`) 가독성 낮음.
- **Decision**:
  **로그 시트 컨벤션으로 통일**:
  - `고객문의_폼`: `접수일시 / 고객명 / 이메일 / 문의내용`
  - `고객문의_로그`: `접수일시 / 고객명 / 이메일 / 문의내용 / 카테고리 / 복잡도 / 처리방식`
- **Consequences**:
  - 🟢 매핑 로직 단순화 (양 시트의 4개 컬럼 이름 동일)
  - 🟢 표현식 가독성 향상 (공백 없는 키)
  - 🟡 Google Forms 연동 시 Forms 가 자동 생성하는 `타임스탬프` 컬럼과 이름 불일치 → Forms 쪽에서 컬럼명 수동 rename 필요

---

## ADR-008: 테스트 데이터 추가를 **헬퍼 워크플로우 + bash 스크립트** 로

- **Status**: Accepted (2026-04-21 Session 2)
- **Context**:
  구글 시트에 테스트 행을 손으로 입력하는 과정이 반복되고, 컬럼명 오타·빈 셀·타이밍 race 유발.
- **Alternatives**:
  1. Python + gspread (Service Account) — 별도 GCP 셋업 필요
  2. Python + User OAuth (installed app flow) — Desktop OAuth Client 추가 생성 필요
  3. Google Apps Script Web App — 배포 과정 복잡
  4. **n8n 헬퍼 워크플로우 (Webhook → Sheet Append)** — 기존 credential 재사용
- **Decision**:
  방법 4 선택. 독립 n8n 워크플로우 `테스트 문의 추가 헬퍼` (ID `91O4quTAcVPxwkJy`) + `scripts/add-test.sh` 한 줄 실행.
- **Consequences**:
  - 🟢 추가 셋업 제로 (기존 Google Sheets OAuth 재사용)
  - 🟢 n8n 학습 효과 (Webhook 트리거 패턴 경험)
  - 🟡 n8n 이 켜져 있어야 동작 (로컬 개발 중에는 늘 켜있으므로 OK)
  - 🟡 헬퍼 워크플로우도 운영 대상에 추가됨 (단순하지만 관리 포인트)

---

## ADR-009: Parse Classification Code 노드는 **다중 아이템 반복 처리**

- **Status**: Accepted (2026-04-21 Session 2)
- **Context**:
  초기 구현: `const g = $input.first().json;` — Code 노드가 첫 번째 아이템만 처리.
  Sheets Trigger 폴링 주기 내 여러 행 추가 시 뒷 아이템 누락.
- **Decision**:
  `$input.all().map((item, i) => {...})` 로 변경. 각 아이템마다 `$('On New Inquiry Row').all()[i]` 와 짝지어 처리.
- **Consequences**:
  - 🟢 배치 폴링 (여러 행 동시 추가) 에 대응
  - 🟢 Switch 가 각 아이템을 올바른 경로로 라우팅
  - 🟡 Code 노드 `$ usage detected` validator warning 발생 (false positive, 실동작 정상)

---

## ADR-010: 워크플로우 업데이트는 **REST PUT 전체 치환** 을 우선 경로로

- **Status**: Accepted (2026-04-21 Session 2)
- **Context**:
  n8n-mcp 의 `n8n_update_partial_workflow` 로 `updateNode` 호출 시 **다른 노드의 기본값 필드 (`resource`, `operation`, `columns.value` 등) 가 strip** 되는 sanitization 이슈가 세션 중 여러 번 재발.
- **Decision**:
  큰 폭 변경이 필요할 때는 **전체 워크플로우 상태를 로컬에서 빌드한 뒤 `PUT /api/v1/workflows/{id}` 로 원자적 치환**.
  작은 변경(단일 필드 patch)은 `updateNode` 유지.
- **Consequences**:
  - 🟢 부작용 없는 원자 업데이트
  - 🟡 `settings` 필드가 엄격해서 불필요 키(`availableInMCP`, `saveExecutionProgress` 등) 보내면 `additional properties` 에러 → minimal settings 로 제한

---

## 향후 검토 대상 (Not Yet Decided)

- **ADR-TBD**: Switch fallback 출력 (기타 복잡도) 처리 방안
- **ADR-TBD**: Error Trigger Workflow 도입 여부 (Gmail/Sheets 레벨 에러 알림)
- **ADR-TBD**: 프롬프트 버전 관리 및 A/B 테스트 체계
- **ADR-TBD**: 비용/사용량 모니터링 자동화 (OpenAI usage dashboard 주간 리포트)
