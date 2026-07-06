---
name: meta-ads-setup
description: Use when setting up Meta Ads MCP integration with Claude — auto-detects CLI vs Desktop environment, registers MCP server, tests connection, generates prompt templates, and schedules weekly performance reports.
---

# Meta Ads Setup

Meta Ads MCP 초기 세팅 자동화. 순서대로 실행. 각 단계 실패 시 멈추고 원인 출력.

## Step 1 — 환경 감지

환경변수로 Claude Code CLI vs Desktop 판별:

```bash
echo $CLAUDE_CODE_ENTRYPOINT
echo $CLAUDE_SESSION_ID
```

- 둘 중 하나라도 값 있음 → **CLI 경로** (Step 2-A)
- 둘 다 없음 → **Desktop 경로** (Step 2-B)

## Step 2-A — MCP 등록 (CLI)

`~/.claude/settings.json` 읽기. `mcpServers` 키에 아래 추가. 기존 항목 유지하고 `meta-ads`만 추가:

```json
{
  "mcpServers": {
    "meta-ads": {
      "type": "url",
      "url": "https://mcp.facebook.com/ads"
    }
  }
}
```

저장 후 `/reload-plugins` 실행.

## Step 2-B — MCP 등록 (Desktop)

1. Claude 앱 좌하단 **Customize** 클릭
2. **Connectors** → **+** → **Add Custom Connector**
3. Name: `Meta Ads` / URL: `https://mcp.facebook.com/ads`
4. 저장 → 새 대화 시작

## Step 3 — 연결 테스트

아래 요청으로 Meta Ads MCP 호출:

```
Use Meta Ads MCP to list my ad accounts
```

결과 판별:

| 결과 | 원인 | 처리 |
|------|------|------|
| 계정 1개 이상 응답 | SUCCESS | Step 4 진행 |
| 인증 오류 / 로그인 요청 | OAuth 미완료 | Meta 계정 로그인 후 재시도 |
| 빈 응답 / 권한 없음 | 계정 미활성화 | Meta 단계적 출시 중 — 대기 |
| 타임아웃 | 서버 문제 | 잠시 후 재시도 |

**SUCCESS 아니면 Step 4 진행 안 함.**

## Step 4-A — 프롬프트 템플릿 생성

현재 작업 디렉토리에 `meta-ads-prompts/` 폴더 생성 후 파일 3개 작성.
각 파일 내용은 이 스킬 파일 옆 `prompts/` 폴더 참고:

- `meta-ads-prompts/campaign-create.md` ← `prompts/campaign-create.md` 내용 복사
- `meta-ads-prompts/performance-analysis.md` ← `prompts/performance-analysis.md` 내용 복사
- `meta-ads-prompts/weekly-report.md` ← `prompts/weekly-report.md` 내용 복사

## Step 4-B — 주간 보고서 자동화

`schedule` 스킬 호출로 매주 월요일 09:00 KST scheduled agent 등록:

```
Use the schedule skill to create a weekly routine that runs every Monday at 00:00 UTC (09:00 KST).
Task: Use Meta Ads MCP to pull last week's performance data and generate a summary report
covering ROAS, CTR, frequency, and total spend by campaign. Format as markdown table.
```

---

## 완료 체크리스트

- [ ] Meta Ads MCP 등록됨
- [ ] 광고 계정 연결 확인
- [ ] 프롬프트 템플릿 3개 생성됨
- [ ] 주간 보고서 자동화 등록됨

---

## 주의사항

- **즉시 반영:** 기존 캠페인 수정은 초안 없이 실제 계정에 즉시 적용됨. 신규 캠페인은 자동 일시정지로 생성.
- **토큰 한도:** 29개 도구 로드 시 55K~134K 토큰 소비. 분석 대화와 수정 대화 분리 권장.
- **구독 필요:** Claude Pro 또는 Max 이상. 무료 플랜 미지원.
- **단계적 출시:** 일부 계정은 Meta MCP 아직 미활성화 상태일 수 있음.
- **Meta Ads 전용:** Google Ads, TikTok Ads 등 타 플랫폼은 별도 연결 필요.
