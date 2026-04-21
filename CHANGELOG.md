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

## [2026-04-21] Session Summary

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
