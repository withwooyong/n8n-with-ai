# SOP: 고객 문의 자동 응대 시스템

> **Standard Operating Procedure**
> 최종 업데이트: 2026-04-21

---

## 1. 개요

### 1.1 워크플로우 이름
**고객 문의 자동 응대 시스템**

### 1.2 목적
고객이 제출한 문의를 AI로 자동 분류하여,
- **단순 문의**는 즉시 자동 답변 발송
- **확인 필요 문의**는 담당자 검토 후 수동 발송

이를 통해 **응대 속도 향상**과 **품질 관리**를 동시에 달성한다.

### 1.3 기대 효과
| 지표 | 효과 |
|------|------|
| 1차 응답 시간 | 수 시간 → 즉시 |
| 담당자 부하 | 전체 문의 → 확인필요 문의만 |
| 응대 누락 | 수동 체크 → 전수 로깅 |

---

## 2. 트리거 (Trigger)

| 항목 | 값 |
|------|------|
| 트리거 유형 | Google Sheets Trigger (`onRowAdded`) |
| 소스 | Google Forms 제출 시 자동 연동되는 응답 시트 |
| 시트 링크 | `https://docs.google.com/spreadsheets/d/YOUR_SHEET_ID` |
| 시트 이름 | `고객문의_폼` |
| 감시 이벤트 | 새 행(Row) 추가 |
| 폴링 주기 | 1분 (n8n 기본값) |

### 2.1 입력 데이터 스키마 (`고객문의_폼`)

| 컬럼명 | 타입 | 예시 |
|--------|------|------|
| `접수일시` | DateTime | `2026-04-21 10:32:15` |
| `고객명` | String | `홍길동` |
| `이메일` | Email | `hong@example.com` |
| `문의내용` | Text | `주문한 제품이 아직 도착하지 않았습니다.` |

> 컬럼명은 `고객문의_로그` 시트와 통일되어 있어 n8n 내부 매핑 불필요. Google Forms 연동 시 Forms 측 응답 컬럼명을 이 이름으로 rename 한다.

---

## 3. 처리 로직 (Processing Logic)

### 3.1 전체 흐름도

```
[Google Sheets Trigger]
        │
        ▼
[Gemini: 분류 + 복잡도 판단]
        │
        ├─ 단순문의 ─────▶ [Gemini: 답변 생성] ─▶ [Gmail: 즉시 발송]
        │                                            │
        │                                            ▼
        │                                      [Sheets: 자동발송 로깅]
        │
        └─ 확인필요 ─────▶ [Gemini: 답변 초안] ─▶ [Gmail: 초안 생성]
                                                     │
                                                     ▼
                                            [Slack #customer-support 알림]
                                                     │
                                                     ▼
                                            [Sheets: 수동확인 로깅]
```

### 3.2 Step 1 — 문의 내용 AI 분석

**노드**: OpenAI (`resource: "text"`, `operation: "response"` — Responses API)
**모델**: `gpt-4o-mini`
**Response Format**: JSON (프롬프트로 형식 강제)
**Simplify Output**: `true`

#### 3.2.1 시스템 프롬프트

```
당신은 고객 문의를 분류하는 전문 어시스턴트입니다.
다음 기준에 따라 문의를 분석하고, 반드시 JSON 형식으로만 응답하세요.

[카테고리]
- 제품문의: 제품 사양, 사용법, 재고 등에 대한 질문
- 배송문의: 배송 상태, 예정일, 주소 변경 등
- 환불요청: 환불, 교환, 취소에 대한 요청
- 기타: 위 카테고리에 해당하지 않는 문의

[복잡도]
- 단순문의: 답변이 정형화되어 있고, 개인정보 확인이나 정책 판단이 불필요한 문의
- 확인필요: 개인 주문 정보 확인이 필요하거나, 환불/교환처럼 정책 판단이 필요하거나, 감정적 컴플레인이 포함된 문의

[출력 형식]
{
  "category": "제품문의 | 배송문의 | 환불요청 | 기타",
  "complexity": "단순문의 | 확인필요",
  "reason": "판단 근거 한 줄 요약"
}
```

#### 3.2.2 유저 프롬프트

```
고객명: {{ $json["고객명"] }}
이메일: {{ $json["이메일"] }}
문의 내용:
---
{{ $json["문의내용"] }}
---

위 문의를 분류해주세요.
```

#### 3.2.3 출력 예시

```json
{
  "category": "배송문의",
  "complexity": "확인필요",
  "reason": "개별 주문번호 확인이 필요한 배송 지연 문의"
}
```

### 3.3 Step 2 — 분기 (Switch / IF 노드)

**분기 조건**: `{{ $json.complexity }}`

| 값 | 다음 경로 |
|----|-----------|
| `단순문의` | 3.4 자동 발송 플로우 |
| `확인필요` | 3.5 수동 확인 플로우 |

### 3.4 단순 문의 플로우 — 자동 발송

#### 3.4.1 AI 답변 생성

**노드**: OpenAI (`resource: "text"`, `operation: "response"`)
**모델**: `gpt-4o-mini`

**시스템 프롬프트**:
```
당신은 고객 응대 전문가입니다.
다음 원칙에 따라 고객 문의에 대한 이메일 답변을 한국어로 작성하세요.

- 정중하고 친근한 톤
- 핵심 답변을 먼저 제시하고 근거는 뒤에 간략히
- 인사말, 본문, 맺음말 구조로 작성
- 200~400자 이내
- 개인정보(주문번호, 금액 등) 임의 생성 금지
- 추가 확인이 필요한 경우 "문의 주시면 재확인 후 안내드리겠습니다" 라고 안내
```

**유저 프롬프트**:
```
카테고리: {{ $json.category }}
고객명: {{ $('Google Sheets Trigger').item.json["고객명"] }}
문의 내용:
{{ $('Google Sheets Trigger').item.json["문의내용"] }}

위 내용에 대한 답변 이메일 본문을 작성해주세요.
```

#### 3.4.2 Gmail 발송

**노드**: Gmail (`sendEmail`)

| 파라미터 | 값 |
|----------|------|
| To | `{{ $('Parse Classification').item.json.customerEmail }}` |
| Subject | `[고객센터] {{ $('Parse Classification').item.json.category }} 문의에 대한 답변` |
| Body | `{{ $json.output[0].content[0].text }}` |
| Email Type | HTML |

> OpenAI Responses API 의 응답 본문은 `$json.output[0].content[0].text` 경로에 위치한다 (simplify 옵션과 무관).

#### 3.4.3 로깅

- **처리방식** 필드에 **`자동발송`** 기록 (3.6 참조)

### 3.5 확인 필요 플로우 — 수동 검토

#### 3.5.1 AI 답변 초안 생성

3.4.1과 **동일한 프롬프트**를 사용하되, 담당자가 수정할 것을 전제로 한다.

#### 3.5.2 Gmail 초안(Draft) 생성

**노드**: Gmail (`createDraft`) — **즉시 발송하지 않음**

| 파라미터 | 값 |
|----------|------|
| To | `{{ $('Parse Classification').item.json.customerEmail }}` |
| Subject | `[검토 필요] {{ $('Parse Classification').item.json.category }} - {{ $('Parse Classification').item.json.customerName }}` |
| Body | `{{ $json.output[0].content[0].text }}` |

> 출력된 **draft ID / URL**을 다음 Slack 알림에 포함한다.

#### 3.5.3 Slack 알림

**노드**: Slack (`postMessage`)
**채널**: `#customer-support`

**메시지 템플릿**:
```
:bell: *새 문의가 도착했습니다. 확인 후 발송해주세요.*

• *고객명*: {{ $('Google Sheets Trigger').item.json["고객명"] }}
• *이메일*: {{ $('Google Sheets Trigger').item.json["이메일"] }}
• *카테고리*: {{ $('AI 분석').item.json.category }}
• *판단 근거*: {{ $('AI 분석').item.json.reason }}

*문의 내용*
>>> {{ $('Google Sheets Trigger').item.json["문의내용"] }}

*AI 답변 초안*
```
{{ $('AI 답변 초안').item.json.text }}
```

:pencil: Gmail 초안 열기: {{ $('Gmail: Draft').item.json.draftUrl }}
```

#### 3.5.4 로깅

- **처리방식** 필드에 **`수동확인`** 기록 (3.6 참조)

---

## 4. 로깅 (Logging)

### 4.1 로그 대상
분기와 무관하게 **모든 문의**는 Google Sheets `고객문의_로그` 시트에 1행씩 append 된다.

### 4.2 스키마 (`고객문의_로그`)

| 컬럼명 | 출처 | 예시 |
|--------|------|------|
| `접수일시` | Trigger `접수일시` | `2026-04-21 10:32:15` |
| `고객명` | Trigger | `홍길동` |
| `이메일` | Trigger | `hong@example.com` |
| `문의내용` | Trigger | `주문한 제품이 ...` |
| `카테고리` | AI 분석 | `배송문의` |
| `복잡도` | AI 분석 | `확인필요` |
| `처리방식` | 분기 결과 | `자동발송` or `수동확인` |

### 4.3 구현 노드
- 노드: Google Sheets (`appendRow`)
- 두 분기 모두 마지막에 동일한 Sheets 노드로 수렴(Merge)시키거나, 분기별로 각각 append 한다.

---

## 5. 에러 처리 (Error Handling)

### 5.1 재시도 정책

| 대상 노드 | 재시도 횟수 | 재시도 간격 |
|-----------|-------------|-------------|
| AI 분석 (OpenAI) | **3회** | 5초 |
| AI 답변 생성 (OpenAI) | **3회** | 5초 |
| AI 답변 초안 (OpenAI) | **3회** | 5초 |

n8n 노드 설정 → `Settings` → `Retry On Fail: true`, `Max Tries: 3`, `Wait Between Tries: 5000ms`

> 간격을 5초로 둔 이유: 외부 LLM API 의 일시적 503/429 가 보통 몇 초 내 회복됨. 2초는 너무 공격적이고 10초 이상은 전체 응답 시간 악화. 429(rate limit) 상황에서 retry 횟수 ↑ 는 오히려 쿼터를 더 소모하므로 3회 유지.

### 5.2 재시도 실패 시 알림

3회 재시도 후에도 실패하면 **Error Trigger 워크플로우** 또는 해당 노드의 `On Error` 분기로 이동하여 Slack에 알린다.

**채널**: `#error-alert`

**메시지 템플릿** (실제 운영 기준 — `$json.error` 는 문자열이므로 객체 접근 금지):
```
:rotating_light: *고객 문의 워크플로우 실패*

• *에러 메시지*: {{ $json.error || ($json.error && $json.error.message) || $json.message || '내용 없음' }}
• *고객명*: {{ $('On New Inquiry Row').item.json['고객명'] || $json.customerName || 'unknown' }}
• *이메일*: {{ $('On New Inquiry Row').item.json['이메일'] || $json.customerEmail || 'unknown' }}
• *문의내용*: {{ $('On New Inquiry Row').item.json['문의내용'] || $json.inquiry || 'unknown' }}
• *카테고리*: {{ $json.category || 'N/A' }}
• *복잡도*: {{ $json.complexity || 'N/A' }}
• *실행 ID*: {{ $execution.id }}
• *Execution URL*: {{ $execution.resumeUrl || $execution.url }}

담당자 수동 확인이 필요합니다.
```

> 초기 버전은 `$json.error.node.name` 같은 객체 접근을 가정했으나, 실제로는 `$json.error` 가 **에러 메시지 문자열** 이므로 fallback 체인을 두어야 한다.

### 5.3 담당자 대응 절차
1. Slack `#error-alert` 알림 수신
2. n8n Executions 페이지에서 실패 원인 확인
3. 고객에게 **수동 회신**
4. 원인이 외부 API 장애면 n8n에서 **재실행(Retry Execution)**
5. 원인이 프롬프트/스키마 문제면 워크플로우 수정 후 회고 기록

---

## 6. 사용 서비스 (Services)

| 서비스 | 용도 | 필요 자격증명 |
|--------|------|----------------|
| Google Sheets | 입력 트리거, 로깅 | Google OAuth2 |
| **OpenAI** | 문의 분류, 답변 생성 | API Key (`gpt-4o-mini`, Responses API) |
| Gmail | 이메일 발송 / 초안 생성 | Google OAuth2 |
| Slack | 알림 (`#customer-support`, `#error-alert`) | Bot Token (`chat:write` + `chat:write.public` + `channels:read`) |

---

## 7. 운영 체크리스트

### 7.1 배포 전
- [ ] Google Sheets 시트 ID 및 시트명 치환 (`YOUR_SHEET_ID`, `고객문의_폼`, `고객문의_로그`)
- [ ] OpenAI API 키 등록 (`gpt-4o-mini` 호출 가능, Responses API 지원 필요)
- [ ] Slack 봇이 `#customer-support`, `#error-alert` 채널에 초대되어 있는지 확인
- [ ] Gmail 발신 계정 OAuth 범위에 `gmail.send`, `gmail.compose` 포함 확인
- [ ] 테스트 문의로 **단순문의 / 확인필요** 두 케이스 각각 End-to-End 실행 (헬퍼: `./scripts/add-test.sh`)
- [ ] 에러 처리 경로 테스트 (OpenAI 모델명 일시 `gpt-invalid-model` 변경 후 `#error-alert` 수신 확인)

### 7.2 운영 중 모니터링
- **일 단위**: `고객문의_로그` 시트에서 자동발송 vs 수동확인 비율 확인
- **주 단위**: OpenAI 분류 품질 샘플링 검수 (잘못 분류된 케이스 수집 → 프롬프트 개선), 토큰/비용 사용량 확인
- **월 단위**: 실패 실행 수, 평균 응답 시간 리포트

### 7.3 변경 관리
- 프롬프트 수정 시 **이전 버전 주석 보존** + 변경일/사유 기록
- 워크플로우 구조 변경은 n8n에서 `Duplicate` 후 테스트 → 검증 완료 시 교체
- 본 SOP 문서 역시 동일한 변경분을 **변경 이력** 섹션에 남긴다

---

## 8. 변경 이력

| 일자 | 버전 | 변경 내용 | 작성자 |
|------|------|-----------|--------|
| 2026-04-21 | v1.0 | 최초 작성 | - |
| 2026-04-21 | v1.1 | 입력 컬럼명 통일 (`이메일 주소`/`문의 내용`/`타임스탬프` → `이메일`/`문의내용`/`접수일시`) | Ted |
| 2026-04-21 | v1.2 | AI provider 교체: **Google Gemini → OpenAI gpt-4o-mini** (Responses API). Gemini 무료 등급 503/429 빈발로 전환. 응답 경로 `$json.mergedResponse` → `$json.output[0].content[0].text` | Ted |
| 2026-04-21 | v1.3 | Retry 간격 2초 → 5초 상향. Alert Error Slack 메시지 표현식 현실화 (문자열 error 필드 대응). Parse Classification Code 다중 아이템 처리 (`$input.all()`) 지원 | Ted |
