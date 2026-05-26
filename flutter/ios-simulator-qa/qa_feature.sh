#!/bin/bash
# 신규 기능 QA 템플릿 — PR 마다 해당 플로우만 테스트
# 사용: ./qa/qa_feature.sh
# 수정: FEATURE_NAME, steps 섹션만 바꾸면 됨

UDID=$(xcrun simctl list devices | grep Booted | grep -oE '[A-F0-9-]{36}' | head -1)
BUNDLE="com.example.yourapp"   # ← iOS Bundle ID로 변경 (Runner/Info.plist > CFBundleIdentifier)
FEATURE_NAME="input_flow"   # ← 기능 이름 변경
SS="$HOME/tmp/qa/${FEATURE_NAME}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$SS"

if [ -z "$UDID" ]; then echo "❌ 부팅된 시뮬레이터 없음"; exit 1; fi
echo "🧪 기능 QA: $FEATURE_NAME"
echo "📁 스크린샷: $SS"

find_xy() {
  idb ui describe-all --udid $UDID 2>/dev/null | python3 -c "
import json,sys
data=json.load(sys.stdin)
for el in data:
  if el.get('AXUniqueId') == '$1' and el['frame']['width'] > 0:
    f=el['frame']
    print(int(f['x']+f['width']/2), int(f['y']+f['height']/2))
    break
"
}

find_label() {
  idb ui describe-all --udid $UDID 2>/dev/null | python3 -c "
import json,sys
data=json.load(sys.stdin)
for el in data:
  if el.get('AXLabel') == '$1' and el['frame']['width'] > 10:
    f=el['frame']
    print(int(f['x']+f['width']/2), int(f['y']+f['height']/2))
    break
"
}

tap_id() {
  local coords=$(find_xy "$1")
  if [ -z "$coords" ]; then echo "  ⚠️  $1 못찾음"; return 1; fi
  idb ui tap --udid $UDID $coords && echo "  ✅ tap $1"
  sleep "$2"
}

tap_label() {
  local coords=$(find_label "$1")
  if [ -z "$coords" ]; then echo "  ⚠️  '$1' 못찾음"; return 1; fi
  idb ui tap --udid $UDID $coords && echo "  ✅ tap '$1'"
  sleep "$2"
}

type_text() {
  idb ui tap --udid $UDID $1 $2   # 필드 먼저 탭
  sleep 0.3
  idb ui type --udid $UDID "$3"
  echo "  ✅ type '$3'"
  sleep 0.5
}

ss() { xcrun simctl io $UDID screenshot "$SS/$1.png" 2>/dev/null && echo "  📸 $1"; }

# ─────────────────────────────────────────
# 앱 실행 + 초기 상태
# ─────────────────────────────────────────
xcrun simctl launch $UDID $BUNDLE > /dev/null
sleep 3
ss "00_start"

# ─────────────────────────────────────────
# 신규 기능 플로우 — 여기만 수정
# ─────────────────────────────────────────
echo ""
echo "=== 당첨번호 입력 플로우 ==="

# 1. 입력 FAB 탭
SCREEN_CENTER=$(idb ui describe-all --udid $UDID 2>/dev/null | python3 -c "
import json,sys; d=json.load(sys.stdin)
app=[e for e in d if e.get('type')=='Application'][0]
print(int(app['frame']['width']/2))
")
TAB_Y=$(find_xy "tab_홈" | awk '{print $2}')
idb ui tap --udid $UDID $SCREEN_CENTER $TAB_Y
sleep 1.5
ss "01_input_sheet_open"

# 2. 회차 입력
ROUND_FIELD=$(find_xy "input_round_number")
if [ -n "$ROUND_FIELD" ]; then
  type_text $ROUND_FIELD "1150"
  ss "02_round_entered"
else
  # key 없으면 좌표 직접 탭 (시트 내 첫번째 필드 근처)
  echo "  ⚠️  input_round_number key 없음 — 좌표 직접 탭"
  idb ui tap --udid $UDID 155 780   # 회차 필드 좌표 (기기마다 다를 수 있음)
  sleep 0.3
  idb ui type --udid $UDID "1150"
  ss "02_round_entered"
fi

# 3. 저장 버튼
tap_id "input_submit_button" 1
ss "03_after_save"

# ─────────────────────────────────────────
# 결과 검증 — Claude 가 스크린샷 보고 판단
# ─────────────────────────────────────────
echo ""
echo "=== 검증 포인트 ==="
echo "  □ 01: 바텀시트 정상 열림?"
echo "  □ 02: 회차 번호 입력됨?"
echo "  □ 03: 저장 후 시트 닫힘 + 홈 복귀?"
echo ""
echo "스크린샷: $SS"
ls "$SS"/*.png | while read f; do echo "  $(basename $f)"; done
