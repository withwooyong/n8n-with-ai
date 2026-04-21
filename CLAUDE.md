# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트 개요

이 저장소는 **n8n 워크플로우를 설계·제작·배포**하는 프로젝트다. 코드베이스가 아니라 워크플로우 명세(SOP) + 로컬 n8n 인스턴스 + n8n-mcp 연동으로 구성된다.

## 워크플로우 제작 프로세스 (필수)

새로운 워크플로우를 만들거나 기존 워크플로우를 수정할 때는 **반드시** 아래 순서를 따른다:

1. **`SOP.md`를 먼저 읽어 워크플로우 로직을 완전히 파악한다.** 추측으로 노드를 구성하지 말 것.
2. n8n Skills(`.claude/skills/n8n-*`)와 n8n-mcp 도구로 최적 노드 구성을 설계한다.
3. n8n-mcp (`mcp__n8n-mcp__*`)로 워크플로우를 생성한다.
4. `mcp__n8n-mcp__n8n_validate_workflow` 와 `mcp__n8n-mcp__n8n_test_workflow` 로 검증한다.
5. 에러 발생 시 `mcp__n8n-mcp__n8n_autofix_workflow` 또는 부분 업데이트로 수정한다.
6. 각 노드의 설정값 누락 / 잘못된 operation 값이 없는지 체크한다.
7. 완료 후 n8n 워크플로우 URL을 사용자에게 제공한다.
8. 완성된 워크플로우 JSON을 `workflow-ver{N}.json` 파일명으로 프로젝트 루트에 저장한다 (예: `workflow-ver1.json`).

### 필수 품질 기준
- 외부 API/AI 호출 노드(Gemini, Gmail, Sheets, Slack 등)는 **에러 핸들링 옵션(Retry On Fail, On Error branch)** 을 반드시 설정한다. 정책은 `SOP.md §5.1`을 따른다.
- 모든 노드 이름은 **영어**로 명확하게 부여한다 (예: `Classify Inquiry`, `Generate Reply`, `Send Gmail`).
- AI/LangChain 노드 설정 시 `operation` / `resource` 값은 실제 존재하는 값만 사용한다 — `mcp__n8n-mcp__get_node` 또는 `mcp__n8n-mcp__validate_node` 로 사전 확인.
- n8n 표현식(`{{ $json.x }}`, `{{ $('Node Name').item.json.y }}`) 은 `SOP.md`에 명시된 참조를 그대로 사용한다.
- 컨텍스트에 맞게 `.claude/skills/n8n-*` 스킬을 단계별로 활용한다 (구성 → 검증 → 배포).

## 로컬 환경 명령어

```bash
# n8n 로컬 인스턴스 기동 (localhost:5678)
docker-compose up -d

# n8n 로그 확인
docker-compose logs -f n8n

# 중지
docker-compose down
```

n8n Editor: <http://localhost:5678>
n8n API: `http://localhost:5678/api/v1` (API 키는 `.mcp.json` 및 `.env` 에 저장)

## 핵심 파일 구조

| 파일 | 역할 |
|------|------|
| `SOP.md` | **진실 공급원(Source of Truth).** 워크플로우의 트리거·로직·로깅·에러처리가 모두 여기에 명세된다. 변경은 여기에 먼저 반영한다. |
| `docker-compose.yml` | 로컬 n8n 컨테이너 정의 (KST, port 5678, volume `n8n_data`) |
| `.mcp.json` | n8n-mcp 서버 설정 (로컬 n8n API 연결). **커밋 금지** (`.gitignore`에 등록됨). |
| `.mcp.json.example` / `.env.example` | 샘플 — 새 환경 셋업 시 복사하여 실제 키 주입 |
| `.claude/skills/n8n-*` | n8n 전용 스킬 (mcp 사용법, 노드 설정, 표현식, 검증, 워크플로우 패턴, Code 노드 JS/Python) |
| `workflow-ver{N}.json` | 완성된 워크플로우의 버전별 export 산출물 |

## n8n-mcp 도구 사용 원칙

- **설계 전**: `mcp__n8n-mcp__search_nodes`, `mcp__n8n-mcp__search_templates`, `mcp__n8n-mcp__get_node` 로 실제 존재하는 노드/파라미터 확인.
- **생성 후 항상**: `mcp__n8n-mcp__n8n_validate_workflow` 실행. 경고/에러가 있으면 반영 후 재검증.
- **실행 테스트**: `mcp__n8n-mcp__n8n_test_workflow` 또는 `mcp__n8n-mcp__n8n_executions` 로 결과 확인.
- **수정 시**: 전체 덮어쓰기(`n8n_update_full_workflow`)보다 `n8n_update_partial_workflow` 를 우선한다.
- Gemini, Gmail, Google Sheets, Slack 등 자격증명은 `mcp__n8n-mcp__n8n_manage_credentials` 로 확인한다 (로컬 n8n UI에서 수동 등록된 상태여야 함).

## Git 규칙

- **커밋 메시지는 한글로 작성.**
- **`git push` 는 사용자가 명시적으로 요청할 때만 실행한다.** 커밋과 푸시를 한 명령에 묶지 않는다.
- `.env`, `.mcp.json` 은 API 키가 포함되어 있으므로 절대 커밋하지 않는다 (`.gitignore` 확인).
