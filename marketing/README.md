# Marketing Skills

마케팅 도구 연동 및 자동화 스킬 모음.

## 스킬 목록

### meta-ads-setup
**트리거:** Meta Ads MCP 연동 세팅 요청 시

Meta Ads MCP 초기 세팅 완전 자동화. 스킬 실행 하나로 아래 전부 완료:

1. **환경 감지** — Claude Code CLI vs Desktop 자동 판별
2. **MCP 등록** — `settings.json` 자동 수정(CLI) 또는 Connectors UI 안내(Desktop)
3. **연결 테스트** — 광고 계정 응답 확인, 실패 원인 진단
4. **프롬프트 템플릿 생성** — 캠페인 생성 / 성과 분석 / 주간 보고서
5. **보고서 자동화** — 매주 월요일 09:00 KST 성과 리포트 scheduled agent 등록

**사전 조건:** Claude Pro 또는 Max 구독 필요

**포함 템플릿:**
- `prompts/campaign-create.md` — 신규 캠페인 생성
- `prompts/performance-analysis.md` — ROAS/CTR/빈도 분석
- `prompts/weekly-report.md` — 주간 성과 요약 보고서
