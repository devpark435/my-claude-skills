---
name: pharpay-figma-screens
description: 팜페이(pharpay) Flutter 앱의 Figma 디자인을 이름으로 찾아 조회할 때 사용. "화면" 페이지의 섹션(홈/복약관리/포인트/쿠폰/알림/온보딩/약국찾기/처방전촬영/내정보/결제/비처방약)→화면 node-id 인덱스를 빠른 캐시로 제공하고, figma MCP로 화면·컴포넌트 스크린샷/디자인 컨텍스트를 가져온다. 사용자가 "팜페이 ~화면/컴포넌트 보여줘·디자인 확인·리팩터·구현", 특정 화면(예: 홈 일상상태, 복약 챌린지, 결제 PIN, 약국 상세)이나 컴포넌트(card/order-state, quickmenu 등) 언급, figma URL 없이 디자인 참조가 필요할 때 반드시 사용. node-id를 모를 때 인덱스를 먼저 보되, 없으면 figma 라이브에서 탐색한다.
---

# 팜페이 Figma 레퍼런스

## Overview

팜페이 디자인은 하나의 Figma 파일에 모여 있다. 이 스킬은 **화면·컴포넌트를 빠르게 찾아 조회**하게 한다.

- **fileKey**: `bwyprjbNmhtD0lEz2ydvmk`
- **화면 페이지**: "화면" `4279:24265` — 현재 디자인이 사는 메인 페이지 (섹션→화면)
- **컴포넌트 라이브러리 페이지**: "Design System" `1974:6052` — 재사용 컴포넌트 원본
- **변환은 별도**: figma→Flutter 코드 변환은 `pharpay-figma` 에이전트 담당. 이 스킬은 **조회/레퍼런스** 중심.

## 핵심 원칙 — 라이브 figma가 진짜 소스, 인덱스는 캐시

`references/screen-map.md`의 node-id 표는 **특정 시점 스냅샷이자 빠른 인덱스일 뿐, 권위 있는 화이트리스트가 아니다.** 디자인은 계속 추가·수정되고 node-id도 바뀐다. 그래서:

1. **인덱스에 있으면** → 바로 그 node-id로 조회. (메타데이터 다시 안 긁어도 됨 — 빠름)
2. **인덱스에 없거나, 컴포넌트를 찾거나, 결과가 비거나 어긋나면** → `get_metadata`로 해당 섹션/페이지를 **라이브 탐색**해 최신 node-id를 얻은 뒤 조회.

"인덱스에 있는 것만 읽는다"는 절대 아니다. 인덱스는 출발점, figma가 사실. 인덱스에 없다고 "없는 화면"이라 단정하지 말 것.

## figma MCP 도구 로드

도구가 deferred면 먼저 로드:
`ToolSearch(query: "select:mcp__figma__get_screenshot,mcp__figma__get_design_context,mcp__figma__get_metadata")`
호출 시 `clientFrameworks: "flutter"`, `clientLanguages: "dart"` 전달. fileKey는 항상 `bwyprjbNmhtD0lEz2ydvmk`.

## 화면 조회

1. 요청한 화면 이름을 [references/screen-map.md](references/screen-map.md)에서 찾아 `node-id` 확보. (섹션 목록은 아래, 화면별 표는 reference 파일.)
2. 못 찾으면 추정한 섹션 id로 `get_metadata(fileKey, nodeId=섹션id)` → 자식 화면 목록에서 이름 매칭.
3. 조회 (목적에 맞게):
   - **개요/구조 + 시안** → `get_design_context(fileKey, nodeId)` 한 번이면 구조 코드 + inline 스크린샷이 함께 온다. 보통 이걸로 충분.
   - **미세 디테일을 눈으로 확대** → inline 스크린샷은 기본 해상도라 작은 텍스트/간격이 흐릴 수 있으니 `get_screenshot(fileKey, nodeId, maxDimension: 2048)`로 고해상도 별도 요청. (개요만 필요하면 생략 — context의 inline로 충분.)

### 큰 화면 — truncation 주의 (정확도 보존)

`get_design_context`는 응답이 약 25k 토큰을 넘으면 **뒷부분이 조용히 잘린다(silent truncation).** 섹션이 많은 긴 화면(예: 일상 `4808:7697`, 수령가능 `4279:28173`)을 한 번에 부르면 하단 카드 구조가 통째로 누락될 수 있다. 이건 토큰을 아끼려는 게 아니라 **완전성**을 위한 절차다 — 한 번에 부른 뒤 잘리는 것보다 나눠 부르는 게 더 정확하다:

1. 먼저 `get_metadata(fileKey, nodeId=화면id)`로 전체 섹션 골격(자식 목록)을 본다. (메타데이터는 이 방식으로 잘 안 잘림.)
2. 필요한 섹션/카드의 자식 node-id로 `get_design_context`를 나눠 부른다 → 각 응답이 상한 안에 들어와 풀 디테일 확보.

화면이 작거나 보통 크기면 1단계 없이 바로 `get_design_context` 한 번이면 된다. 분할은 truncation이 의심될 때만.

## 컴포넌트 조회

화면 안의 컴포넌트(예: `card/order-state`, `quickmenu`, `Section_medication`, `card/store`, `carousel`, `button/cta`)도 따로 구현·참조할 일이 있으므로 **읽을 수 있어야 한다.**

1. **컴포넌트 node-id 인덱스**: 재사용 컴포넌트 마스터/변형 node-id는 [references/component-map.md](references/component-map.md)에서 먼저 찾는다. (컴포넌트 세트 60+종 + `card/order-state` 7변형(review/approved/making/completed/visiting/visited/need) 등 등재.)
2. **화면 맥락 안에서 쓸 때**: 그 화면을 `get_design_context`로 부르면 내부 컴포넌트 코드/구조가 함께 온다. 별도 조회 불필요한 경우 多.
3. **특정 컴포넌트만 단독으로 볼 때**: component-map의 node-id(또는 화면 `get_metadata`로 찾은 `<instance>` id)로 `get_screenshot`/`get_design_context` 조회. 단독 컴포넌트는 `get_screenshot`에 `contentsOnly: true`를 주면 주변 요소 없이 깔끔히 렌더됨.
4. **인덱스에 없으면 라이브**: component-map에 없는 컴포넌트는 Design System 페이지 `1974:6052`(또는 해당 화면)를 `get_metadata`로 탐색. 아이콘 937종은 인덱스화 안 되어 있으니 항상 라이브 검색.

컴포넌트는 보통 폭 ≈370px의 `<instance>`(이름에 `card/`, `Section_`, `button/`, `carousel`, `quickmenu` 등)다. 화면 프레임(폭 ≈402px, Status Bar/header+body)과 구분되지만, **둘 다 조회 대상**이다 — 폭 기준은 분류용이지 배제용이 아니다.

## 섹션 목록 ("화면" 페이지)

| 섹션 | node-id | 화면 수(스냅샷) |
|------|---------|--------|
| 홈 | `4279:24269` | 10 |
| 복약관리 | `4279:25436` | 12 |
| 포인트 | `4279:25734` | 3 |
| 쿠폰 | `4279:25850` | 5 |
| 알림 히스토리 | `4557:41490` | 1 |
| 온보딩 | `4475:23729` | 17 |
| 약국 찾기 탭 | `4475:24624` | 5 |
| 처방전촬영 플로우 | `4475:25821` | 15 (+중첩 GIF `4475:26271`) |
| 내정보 | `4475:27748` | 14 |
| 결제 | `4601:11250` | 6 (+중첩 카드등록 `4977:48411`) |
| 비처방약 | `4888:44790` | 7 |
| archive (보관/구버전) | `4632:27624` | 혼재 — 신규 작업엔 비권장 |

→ 화면별 정확한 이름·node-id는 **[references/screen-map.md](references/screen-map.md)**. "화면 수"는 스냅샷 시점 값이라 실제는 더 많을 수 있다.

## 주의

- **node-id는 디자인 편집 시 바뀐다.** 인덱스에서 못 찾거나 빈/엉뚱한 결과면 섹션 id로 `get_metadata` 재조회. 추측 node-id를 그대로 쓰지 말 것.
- **인덱스 ≠ 전체 목록.** 신규 화면/컴포넌트는 인덱스에 없을 수 있으니, 사용자가 인덱스에 없는 걸 요청하면 곧장 라이브 탐색.
- **간편모드**: "화면" 페이지엔 간편모드 섹션이 없지만(거기서 매칭되는 "간편결제"/"간편로그인"은 기능명), **Design System 페이지에 `간편모드` 섹션 `5174:46315`이 존재**한다(quickmenu `easy-mode` 변형 `5174:46274` 연관). 사용자가 간편모드를 찾으면 이 섹션을 `get_metadata`로 탐색.
- **archive 섹션**은 정리/구버전 보관용(구 목업 w=375 다수). 신규 리팩터 기준 아님.
- 화면이 어느 섹션인지 모르면 사용자에게 되묻기 전에 인덱스 전체에서 이름 검색 → 그래도 없으면 페이지 `get_metadata`.
