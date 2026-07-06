---
name: flutter-ios-simulator-qa
description: Use when setting up iOS simulator QA automation for a Flutter project, generating or adapting QA scripts, running tap/swipe/screenshot tests, or when asked to test specific features or scopes on the simulator.
---

# Flutter iOS Simulator QA

## Overview

idb + xcrun simctl 로 Claude Code 가 시뮬레이터 직접 조작.

**스크립트 저장 위치:** `.claude/qa/` (프로젝트 루트 기준)
→ `.claude/` 가 `.gitignore` 에 있으면 자동으로 추적 제외. 레포 오염 없음.

```
project/
  .claude/
    qa/
      qa_regression.sh   ← 스킬이 자동 생성
      qa_feature.sh      ← 스킬이 자동 생성
```

**"QA 설정해줘" 요청 시 Claude 는 아래 자동 생성 절차를 따른다.**

## 설치

```bash
brew tap facebook/fb
brew install facebook/fb/idb-companion
python3 -m pip install fb-idb --break-system-packages
```

---

## 자동 생성 절차 (Claude 가 따를 것)

"QA 설정해줘" / "QA 스크립트 만들어줘" 요청 시 아래 순서 실행.

### Step 1 — 프로젝트 분석 (Bash 로 실행)

```bash
# Bundle ID
grep -r "PRODUCT_BUNDLE_IDENTIFIER" ios/Runner.xcodeproj/project.pbxproj | grep -v Test | head -1

# 탭 구조 파일 찾기
grep -r "BottomNavigationBar\|_TabItem\|PillBottomBar\|tab_bar\|MainTabScreen" lib/ --include="*.dart" -l

# 기존 Semantics identifier 확인
grep -rn "Semantics" lib/ --include="*.dart" | grep "identifier"
```

### Step 2 — 탭 파일 읽고 구조 파악

탭 파일을 Read 로 열어서:
- 탭 라벨 목록 추출 (예: `['홈', '예약', '채팅', '마이']`)
- Semantics 달려 있는지 확인
- CTA 버튼 텍스트 확인 (HomeScreen 파일 읽기)

### Step 3 — Semantics 누락 시 사용자에게 고지

코드 수정은 직접 하지 않고, 어느 파일 몇 번째 줄에 무엇을 추가해야 하는지 알려줌.
(사용자가 직접 복붙)

### Step 4 — `.claude/qa/` 에 스크립트 생성

```bash
mkdir -p .claude/qa
```

분석 결과로 아래 템플릿 변수 섹션을 채워 `.claude/qa/qa_regression.sh` 생성.
생성 후 `chmod +x .claude/qa/qa_regression.sh` 실행.

### Step 5 — .gitignore 확인

```bash
grep "\.claude" .gitignore
```

없으면 사용자에게 `.gitignore` 에 `.claude/` 추가 권고.

---

## 필수 코드 수정 (스크립트 실행 전 직접 추가)

스크립트가 요소를 찾으려면 `Semantics(identifier:)` 래핑 필수. 아래 패턴을 프로젝트에 복붙.

### 패턴 A — 탭바 아이템 (GestureDetector 기반)

탭 아이템을 `List.generate` 로 만드는 경우:

```dart
// 기존
return GestureDetector(
  onTap: ...,
  child: Column(...),
);

// 수정 — GestureDetector 바깥에 Semantics 추가
return Semantics(
  identifier: 'tab_${labels[index]}',  // labels 변수명은 프로젝트마다 다름
  child: GestureDetector(
    onTap: ...,
    child: Column(...),
  ),  // GestureDetector 닫기
);  // Semantics 닫기
```

### 패턴 B — 탭바 아이템 (개별 위젯 기반)

```dart
// 기존
_TabItem(label: '홈', onTap: () => context.go('/'))

// 수정 — _TabItem.build() 내부 GestureDetector 에 Semantics 추가
return Expanded(
  child: Semantics(
    identifier: 'tab_$label',  // label 파라미터 활용
    child: GestureDetector(
      onTap: onTap,
      child: ...,
    ),
  ),
);
```

### 패턴 C — CTA / 제출 버튼

```dart
// 기존
ElevatedButton(
  onPressed: onPressed,
  child: const Text('버튼 텍스트'),
)

// 수정
Semantics(
  identifier: 'home_cta_button',  // identifier 는 영문 권장
  child: ElevatedButton(
    key: const ValueKey('home_cta_button'),
    onPressed: onPressed,
    child: const Text('버튼 텍스트'),
  ),
)
```

### 주의사항

- `Semantics` 닫는 괄호 `)` 하나 추가 필요 (기존 위젯 닫는 괄호 뒤에)
- identifier 는 **영문 + 언더스코어** 권장 (한글도 작동하지만 스크립트에서 따옴표 처리 주의)
- 빌드 후 `idb ui describe-all` 로 AXUniqueId 노출 여부 반드시 확인

```bash
# 확인 명령어
idb ui describe-all --udid <UDID> 2>/dev/null | python3 -c "
import json,sys
for el in json.load(sys.stdin):
    uid=el.get('AXUniqueId')
    if uid: print(uid, el['frame'])
"
```

---

## 스크립트 템플릿

```bash
#!/bin/bash
# ─────────────────────────────────────────
# 프로젝트별 설정 — 여기만 수정
# ─────────────────────────────────────────
BUNDLE="com.example.myapp"           # ← bundle ID
TAB_IDS=("tab_홈" "tab_설정")       # ← Semantics identifier 목록
CTA_LABEL="시작하기"                 # ← 홈 CTA AXLabel
INPUT_FAB_ID="tab_input"             # ← 입력 FAB identifier (없으면 좌표 사용)
# ─────────────────────────────────────────

UDID=$(xcrun simctl list devices | grep Booted | grep -oE '[A-F0-9-]{36}' | head -1)
SCOPE="${1:-all}"   # 사용: ./qa_regression.sh tabs | input | cta | all
SS="$HOME/tmp/qa/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$SS"

[ -z "$UDID" ] && echo "❌ 부팅된 시뮬레이터 없음" && exit 1
echo "📱 $UDID  🎯 scope=$SCOPE  📁 $SS"

# ── 헬퍼 ──────────────────────────────────
find_xy() {
  idb ui describe-all --udid $UDID 2>/dev/null | python3 -c "
import json,sys
for el in json.load(sys.stdin):
  if el.get('AXUniqueId')=='$1' and el['frame']['width']>0:
    f=el['frame']; print(int(f['x']+f['width']/2),int(f['y']+f['height']/2)); break
"
}
find_label() {
  idb ui describe-all --udid $UDID 2>/dev/null | python3 -c "
import json,sys
for el in json.load(sys.stdin):
  if el.get('AXLabel')=='$1' and el['frame']['width']>10:
    f=el['frame']; print(int(f['x']+f['width']/2),int(f['y']+f['height']/2)); break
"
}
tap_id()    { c=$(find_xy "$1"); [ -z "$c" ] && echo "⚠️ $1 못찾음" && return; idb ui tap --udid $UDID $c; sleep "$2"; echo "  ✅ $1"; }
tap_label() { c=$(find_label "$1"); [ -z "$c" ] && echo "⚠️ '$1' 못찾음" && return; idb ui tap --udid $UDID $c; sleep "$2"; echo "  ✅ '$1'"; }
ss()        { xcrun simctl io $UDID screenshot "$SS/$1.png" 2>/dev/null && echo "  📸 $1"; }
dismiss()   { idb ui tap --udid $UDID 201 300; sleep 1; }  # 모달 닫기

# ── 초기화 ────────────────────────────────
xcrun simctl launch $UDID $BUNDLE > /dev/null; sleep 3
dismiss  # 열린 시트/모달 닫기
home_xy=$(find_xy "${TAB_IDS[0]}")
[ -n "$home_xy" ] && idb ui tap --udid $UDID $home_xy && sleep 1

# ── 탭 네비게이션 ──────────────────────────
if [[ "$SCOPE" == "all" || "$SCOPE" == *"tabs"* ]]; then
  echo "=== 탭 네비게이션 ==="
  ss "01_home"
  for id in "${TAB_IDS[@]}"; do
    tap_id "$id" 1.5
    ss "tab_${id}"
  done
  # 홈 복귀
  [ -n "$home_xy" ] && idb ui tap --udid $UDID $home_xy && sleep 1
fi

# ── 입력 플로우 ────────────────────────────
if [[ "$SCOPE" == "all" || "$SCOPE" == *"input"* ]]; then
  echo "=== 입력 플로우 ==="
  tap_id "$INPUT_FAB_ID" 1.5
  ss "input_sheet_open"
  dismiss
fi

# ── CTA ───────────────────────────────────
if [[ "$SCOPE" == "all" || "$SCOPE" == *"cta"* ]]; then
  echo "=== CTA ==="
  # 스크롤해서 CTA 노출
  idb ui swipe --udid $UDID 201 500 201 200 --duration 0.5; sleep 1
  tap_label "$CTA_LABEL" 2
  ss "after_cta"
fi

echo "=== 완료: $SS ==="
```

---

## 사용법

```bash
./qa/qa_regression.sh           # 전체 (기본)
./qa/qa_regression.sh tabs      # 탭 네비게이션만
./qa/qa_regression.sh input     # 입력 플로우만
./qa/qa_regression.sh cta       # CTA만
./qa/qa_regression.sh tabs,cta  # 복수 지정
```

---

## 핵심 idb 명령어 (실제 작동하는 것만)

```bash
# 연결 확인
idb list-targets
idb connect <udid>

# 탭 (좌표만 지원 — accessibility-identifier 플래그 없음)
idb ui tap --udid <udid> <x> <y>

# 스와이프 (--duration 플래그로 속도 조절)
idb ui swipe --udid <udid> <x1> <y1> <x2> <y2> --duration 0.5

# 텍스트 입력 (필드 탭 후)
idb ui type --udid <udid> "텍스트"

# accessibility tree 조회 → AXUniqueId, AXLabel, 좌표 추출
idb ui describe-all --udid <udid>
```

**⚠️ `--accessibility-identifier` 플래그 없음** — `describe-all` 로 AXUniqueId 찾아 좌표 계산 후 `tap x y` 사용.

## AXUniqueId 매핑 원리

```
Flutter Semantics(identifier: 'foo')
  → iOS AXUniqueId = 'foo'
  → idb describe-all 에서 {"AXUniqueId": "foo", "frame": {...}} 로 노출
  → frame 중심 좌표 계산 → idb ui tap x y
```

`ValueKey` 단독으로는 AXUniqueId 안 됨. `Semantics(identifier:)` 래핑 필수.

## 흔한 실패

| 문제 | 원인 | 해결 |
|------|------|------|
| identifier 못찾음 | 모달/시트 열린 상태 | `dismiss()` 먼저 호출 |
| 스크롤 후에도 CTA 못찾음 | 스크롤 방향 반대 | y1 > y2 = 위로 스크롤 (콘텐츠 아래로) |
| 요소 수 적음 (18개 이하) | 모달이 포커스 가져감 | 모달 닫고 재시도 |
| 빌드 후에도 구버전 실행 | launch 가 캐시 사용 | `xcrun simctl install` 먼저 |
