# Meta Ads Setup Skill — Design

**Date:** 2026-05-26  
**Status:** Approved

---

## Overview

단일 스킬로 Meta Ads MCP 초기 세팅을 완전 자동화한다. 사용자는 스킬 실행 후 MCP 연결, 프롬프트 템플릿, 주간 보고서 자동화까지 전부 갖춘 상태가 된다.

---

## 디렉토리 재편

기존 flat 구조를 카테고리별로 재편한다. 신규 스킬과 동시 진행.

```
claude_skills/
├── flutter/
│   ├── riverpod-patterns/SKILL.md
│   ├── project-bootstrap/SKILL.md
│   ├── golden-tdd/SKILL.md
│   ├── go-router/SKILL.md
│   ├── retrofit-dio/SKILL.md
│   ├── ios-simulator-qa/SKILL.md + qa_*.sh
│   ├── owasp-security/SKILL.md + scripts/ + references/
│   └── figma-mcp/SKILL.md
├── marketing/
│   └── meta-ads-setup/
│       ├── SKILL.md
│       └── prompts/
│           ├── campaign-create.md
│           ├── performance-analysis.md
│           └── weekly-report.md
├── design/
│   └── pharpay-figma/SKILL.md
└── docs/
    └── superpowers/specs/
```

---

## 스킬 메타데이터

- **name:** `meta-ads-setup`
- **위치:** `marketing/meta-ads-setup/SKILL.md`
- **트리거:** "Meta Ads 세팅", "meta ads mcp 연동", "광고 계정 연결"

---

## 실행 흐름 (4단계)

각 단계는 순서대로 실행. 실패 시 즉시 멈추고 원인 + 해결책 출력. 다음 단계 진행 안 함.

### Step 1 — 환경 감지

`CLAUDE_CODE_ENTRYPOINT` 또는 `CLAUDE_SESSION_ID` 환경변수 존재 여부로 CLI vs Desktop 판별.

- **CLI 감지:** `~/.claude/settings.json` 자동 수정 경로로 진행
- **Desktop 감지:** Connectors UI 수동 안내 경로로 진행

### Step 2 — MCP 등록

**CLI 경로:**
```json
// ~/.claude/settings.json에 추가
{
  "mcpServers": {
    "meta-ads": {
      "type": "url",
      "url": "https://mcp.facebook.com/ads"
    }
  }
}
```
등록 후 `/reload-plugins` 실행.

**Desktop 경로:**
1. Claude 앱 열기
2. 좌하단 Customize 클릭
3. Connectors → + → Add Custom Connector
4. 이름: `Meta Ads`, URL: `https://mcp.facebook.com/ads`
5. 저장

### Step 3 — 연결 테스트

Meta Ads MCP를 통해 광고 계정 목록 호출. 응답 판별:

| 결과 | 판단 | 다음 행동 |
|------|------|-----------|
| 계정 1개 이상 응답 | SUCCESS | Step 4 진행 |
| 인증 오류 | OAuth 미완료 | 로그인 재시도 안내 |
| 빈 응답 | 계정 미활성화 | Meta 단계적 출시 안내 |
| 타임아웃 | 서버 문제 | 재시도 또는 대기 안내 |

### Step 4 — 산출물 생성

**4a. 프롬프트 템플릿 3개 생성**

| 파일 | 용도 |
|------|------|
| `prompts/campaign-create.md` | 신규 캠페인 생성 프롬프트 |
| `prompts/performance-analysis.md` | ROAS/CTR/빈도 분석 프롬프트 |
| `prompts/weekly-report.md` | 주간 성과 보고서 프롬프트 |

**4b. 주간 보고서 자동화**

`schedule` 스킬을 통해 scheduled agent 등록:
- 주기: 매주 월요일 오전 9시 (KST)
- 내용: `prompts/weekly-report.md` 기반 지난주 ROAS/CTR 요약

---

## 주의사항 (SKILL.md에 포함)

- **즉시 반영:** 기존 캠페인 수정은 초안 없이 실제 계정에 즉시 적용됨
- **토큰 한도:** 29개 도구 로드 시 55K~134K 토큰 소비. 대화 분리 권장
- **단계적 출시:** 일부 계정은 아직 MCP 미활성화. 오류 시 대기 안내
- **구독 필요:** Claude Pro 또는 Max 이상 필요. 무료 플랜 미지원
- **타 플랫폼 불가:** Meta Ads 전용. Google Ads, TikTok Ads 별도 연결 필요

---

## 타겟 사용자

- Claude Code CLI 사용자 (개발자/마케터)
- Claude Desktop 사용자 (비개발자 마케터)
- 두 환경 모두 단일 스킬로 커버

---

## 범위 외

- 이미지/영상 생성 (Higgs Field MCP 별도)
- 타 광고 플랫폼 연동
- 오가닉 Facebook 페이지 데이터
