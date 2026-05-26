#!/bin/bash
# ─────────────────────────────────────────
# 프로젝트별 설정 — 여기만 수정
# ─────────────────────────────────────────
BUNDLE="com.example.yourapp"   # ← iOS Bundle ID로 변경 (Runner/Info.plist > CFBundleIdentifier)
TAB_IDS=("tab_home" "tab_second" "tab_third" "tab_settings")   # ← 앱 탭 AXUniqueId로 변경
CTA_LABEL="버튼 레이블"   # ← 메인 CTA 버튼 텍스트로 변경
INPUT_FAB_ID=""   # ← FAB AXUniqueId (없으면 빈 문자열)
# ─────────────────────────────────────────

UDID=$(xcrun simctl list devices | grep Booted | grep -oE '[A-F0-9-]{36}' | head -1)
SCOPE="${1:-all}"
SS="$HOME/tmp/qa/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$SS"

[ -z "$UDID" ] && echo "❌ 부팅된 시뮬레이터 없음" && exit 1
echo "📱 $UDID  🎯 scope=$SCOPE  📁 $SS"

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
tap_id()    { c=$(find_xy "$1"); [ -z "$c" ] && echo "  ⚠️  $1 못찾음" && return; idb ui tap --udid $UDID $c; sleep "$2"; echo "  ✅ $1"; }
tap_label() { c=$(find_label "$1"); [ -z "$c" ] && echo "  ⚠️  '$1' 못찾음" && return; idb ui tap --udid $UDID $c; sleep "$2"; echo "  ✅ '$1'"; }
ss()        { xcrun simctl io $UDID screenshot "$SS/$1.png" 2>/dev/null && echo "  📸 $1"; }
dismiss()   { idb ui tap --udid $UDID 201 300; sleep 1; }

# 초기화
xcrun simctl launch $UDID $BUNDLE > /dev/null; sleep 3
dismiss
home_xy=$(find_xy "tab_홈")
[ -n "$home_xy" ] && idb ui tap --udid $UDID $home_xy && sleep 1

# 탭 네비게이션
if [[ "$SCOPE" == "all" || "$SCOPE" == *"tabs"* ]]; then
  echo "=== 탭 네비게이션 ==="
  ss "01_home"
  for id in "${TAB_IDS[@]}"; do
    tap_id "$id" 1.5
    ss "tab_${id}"
  done
  [ -n "$home_xy" ] && idb ui tap --udid $UDID $home_xy && sleep 1
fi

# 입력 플로우
if [[ "$SCOPE" == "all" || "$SCOPE" == *"input"* ]]; then
  echo "=== 입력 플로우 ==="
  # 입력 FAB — 화면 중앙 탭바
  SCREEN_W=$(idb ui describe-all --udid $UDID 2>/dev/null | python3 -c "
import json,sys; d=json.load(sys.stdin)
print(int([e for e in d if e.get('type')=='Application'][0]['frame']['width']))
")
  TAB_Y=$(find_xy "tab_홈" | awk '{print $2}')
  idb ui tap --udid $UDID $((SCREEN_W/2)) $TAB_Y; sleep 1.5
  ss "input_sheet_open"
  dismiss
fi

# CTA
if [[ "$SCOPE" == "all" || "$SCOPE" == *"cta"* ]]; then
  echo "=== CTA ==="
  idb ui swipe --udid $UDID 201 500 201 200 --duration 0.5; sleep 1
  tap_label "$CTA_LABEL" 2
  ss "after_cta"
fi

echo ""
echo "=== 완료 ==="
echo "스크린샷: $SS"
ls "$SS"/*.png | while read f; do echo "  $(basename $f)"; done
