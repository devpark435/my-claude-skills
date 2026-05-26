# Meta Ads Setup Skill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 디렉토리를 카테고리별로 재편하고, Meta Ads MCP 초기 세팅을 완전 자동화하는 스킬을 생성한다.

**Architecture:** 기존 flat 구조를 flutter/, marketing/, design/ 카테고리로 분리. `marketing/meta-ads-setup/`에 SKILL.md + 프롬프트 템플릿 3개 생성. 작업 완료 후 docs/superpowers/ 폴더 삭제.

**Tech Stack:** git mv (히스토리 보존), Markdown SKILL.md

---

## File Map

| 액션 | 경로 |
|------|------|
| 생성 디렉토리 | `flutter/`, `marketing/`, `design/` |
| 이동 (9개) | `flutter-*/` → `flutter/*/` (flutter prefix 제거) |
| 이동 | `pharpay-figma/` → `design/pharpay-figma/` |
| 생성 | `marketing/meta-ads-setup/SKILL.md` |
| 생성 | `marketing/meta-ads-setup/prompts/campaign-create.md` |
| 생성 | `marketing/meta-ads-setup/prompts/performance-analysis.md` |
| 생성 | `marketing/meta-ads-setup/prompts/weekly-report.md` |
| 삭제 | `docs/` (superpowers 임시 문서) |

---

## Task 1: flutter/ 카테고리 디렉토리로 이동

**Files:**
- Move: `flutter-figma-mcp/` → `flutter/figma-mcp/`
- Move: `flutter-go-router/` → `flutter/go-router/`
- Move: `flutter-golden-tdd/` → `flutter/golden-tdd/`
- Move: `flutter-ios-simulator-qa/` → `flutter/ios-simulator-qa/`
- Move: `flutter-owasp-security/` → `flutter/owasp-security/`
- Move: `flutter-project-bootstrap/` → `flutter/project-bootstrap/`
- Move: `flutter-retrofit-dio/` → `flutter/retrofit-dio/`
- Move: `flutter-riverpod-patterns/` → `flutter/riverpod-patterns/`

- [ ] **Step 1: 디렉토리 이동 (git mv로 히스토리 보존)**

```bash
cd /Users/parkhyunryeol/Desktop/claude_skills
git mv flutter-figma-mcp flutter/figma-mcp
git mv flutter-go-router flutter/go-router
git mv flutter-golden-tdd flutter/golden-tdd
git mv flutter-ios-simulator-qa flutter/ios-simulator-qa
git mv flutter-owasp-security flutter/owasp-security
git mv flutter-project-bootstrap flutter/project-bootstrap
git mv flutter-retrofit-dio flutter/retrofit-dio
git mv flutter-riverpod-patterns flutter/riverpod-patterns
```

- [ ] **Step 2: 이동 결과 확인**

```bash
ls flutter/
```

Expected output:
```
figma-mcp  go-router  golden-tdd  ios-simulator-qa  owasp-security  project-bootstrap  retrofit-dio  riverpod-patterns
```

- [ ] **Step 3: 커밋**

```bash
git add -A
git commit -m "refactor: flutter 스킬 flutter/ 카테고리로 이동"
```

---

## Task 2: design/ 카테고리 디렉토리로 이동

**Files:**
- Move: `pharpay-figma/` → `design/pharpay-figma/`

- [ ] **Step 1: 이동**

```bash
git mv pharpay-figma design/pharpay-figma
```

- [ ] **Step 2: 확인**

```bash
ls design/
```

Expected: `pharpay-figma`

- [ ] **Step 3: 커밋**

```bash
git add -A
git commit -m "refactor: pharpay-figma design/ 카테고리로 이동"
```

---

## Task 3: marketing/meta-ads-setup/SKILL.md 생성

**Files:**
- Create: `marketing/meta-ads-setup/SKILL.md`

- [ ] **Step 1: 디렉토리 생성**

```bash
mkdir -p marketing/meta-ads-setup/prompts
```

- [ ] **Step 2: SKILL.md 작성**

`marketing/meta-ads-setup/SKILL.md` 내용:

```markdown
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

`~/.claude/settings.json`에 아래 항목 추가. `mcpServers` 키 이미 있으면 기존 유지하고 `meta-ads`만 추가:

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

`meta-ads-prompts/` 폴더를 현재 작업 디렉토리에 생성 후 파일 3개 작성:

- `meta-ads-prompts/campaign-create.md`
- `meta-ads-prompts/performance-analysis.md`
- `meta-ads-prompts/weekly-report.md`

각 파일 내용은 이 스킬 파일 옆 `prompts/` 폴더 참고.

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
```

- [ ] **Step 3: 파일 존재 확인**

```bash
cat marketing/meta-ads-setup/SKILL.md | head -5
```

Expected:
```
---
name: meta-ads-setup
description: Use when setting up Meta Ads MCP integration with Claude
```

- [ ] **Step 4: 커밋**

```bash
git add marketing/meta-ads-setup/SKILL.md
git commit -m "feat: meta-ads-setup 스킬 SKILL.md 추가"
```

---

## Task 4: 프롬프트 템플릿 3개 생성

**Files:**
- Create: `marketing/meta-ads-setup/prompts/campaign-create.md`
- Create: `marketing/meta-ads-setup/prompts/performance-analysis.md`
- Create: `marketing/meta-ads-setup/prompts/weekly-report.md`

- [ ] **Step 1: campaign-create.md 작성**

`marketing/meta-ads-setup/prompts/campaign-create.md`:

```markdown
새 Meta Ads 캠페인을 생성해줘.

- 캠페인 이름: [이름]
- 목표: [인지도/트래픽/전환/앱 설치]
- 타겟: [나이 범위, 성별, 관심사 키워드]
- 지역: [국가 또는 도시]
- 일 예산: [금액]원
- 기간: [시작일 YYYY-MM-DD] ~ [종료일 YYYY-MM-DD]
- 최적화 이벤트: [구매/장바구니 추가/회원가입/링크 클릭]

캠페인 → 광고 세트 → 광고 순서로 전체 구조 만들어줘.
새로 만든 캠페인은 일시정지 상태로 설정해줘.
```

- [ ] **Step 2: performance-analysis.md 작성**

`marketing/meta-ads-setup/prompts/performance-analysis.md`:

```markdown
지난 [7/14/30]일 Meta Ads 성과를 분석해줘.

아래 지표 기준으로 분석해줘:
1. ROAS 상위 5개 광고와 하위 5개 광고
2. CTR 1% 미만인 광고 세트
3. 빈도 3 이상 광고 (광고 피로도 위험)
4. 예산 소진율 80% 미만인 캠페인
5. 경매 인사이트로 업계 평균 대비 내 지표 위치

이상값 발견 시 원인과 개선 제안도 함께 줘.
결과는 마크다운 테이블로 정리해줘.
```

- [ ] **Step 3: weekly-report.md 작성**

`marketing/meta-ads-setup/prompts/weekly-report.md`:

```markdown
지난주 (월~일) Meta Ads 전체 성과 요약 리포트 만들어줘.

포함 내용:
- 전체 지출 / ROAS / CPC / CTR 요약 수치
- 캠페인별 성과 마크다운 테이블
- 전주 대비 증감률 (% 표시)
- 주목할 트렌드 또는 이상값
- 다음 주 추천 액션 3가지

형식: 마크다운 테이블 포함, 경영진에게 공유 가능한 수준으로 작성.
```

- [ ] **Step 4: 파일 3개 확인**

```bash
ls marketing/meta-ads-setup/prompts/
```

Expected: `campaign-create.md  performance-analysis.md  weekly-report.md`

- [ ] **Step 5: 커밋**

```bash
git add marketing/meta-ads-setup/prompts/
git commit -m "feat: meta-ads-setup 프롬프트 템플릿 3개 추가"
```

---

## Task 5: docs/superpowers/ 임시 문서 삭제

**Files:**
- Delete: `docs/` 전체 (superpowers 브레인스토밍/플랜 임시 파일)

- [ ] **Step 1: 삭제**

```bash
git rm -r docs/
```

- [ ] **Step 2: 확인**

```bash
ls
```

Expected: `docs/` 폴더 없음. `flutter/`, `marketing/`, `design/`, `.claude/` 만 존재.

- [ ] **Step 3: 커밋**

```bash
git commit -m "chore: superpowers 임시 문서 삭제"
```

---

## Task 6: 최종 구조 검증

- [ ] **Step 1: 전체 구조 확인**

```bash
find . -name "SKILL.md" -not -path '*/.git/*' | sort
```

Expected:
```
./design/pharpay-figma/SKILL.md
./flutter/figma-mcp/SKILL.md
./flutter/go-router/SKILL.md
./flutter/golden-tdd/SKILL.md
./flutter/ios-simulator-qa/SKILL.md
./flutter/owasp-security/SKILL.md
./flutter/project-bootstrap/SKILL.md
./flutter/retrofit-dio/SKILL.md
./flutter/riverpod-patterns/SKILL.md
./marketing/meta-ads-setup/SKILL.md
```

- [ ] **Step 2: meta-ads-setup 스킬 name 필드 확인**

```bash
head -4 marketing/meta-ads-setup/SKILL.md
```

Expected:
```
---
name: meta-ads-setup
description: Use when setting up Meta Ads MCP integration with Claude
```

- [ ] **Step 3: 프롬프트 템플릿 확인**

```bash
ls marketing/meta-ads-setup/prompts/
```

Expected: `campaign-create.md  performance-analysis.md  weekly-report.md`

- [ ] **Step 4: 최종 커밋 (변경사항 있을 경우)**

```bash
git status
# 변경사항 없으면 완료. 있으면:
git add -A
git commit -m "chore: 최종 구조 정리"
```
