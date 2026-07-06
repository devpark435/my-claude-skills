#!/usr/bin/env bash
# 동작 주입. 좌표는 실제 픽셀(screencap png 좌표와 동일).
# usage:
#   qa_act.sh tap X Y
#   qa_act.sh swipe X1 Y1 X2 Y2 [MS]
#   qa_act.sh scroll up|down|left|right [MS]   # 화면중앙 기준 자동
#   qa_act.sh text "문자열"
#   qa_act.sh key BACK|HOME|ENTER|TAB|DEL|...
#   qa_act.sh launch <pkg> [url]               # url 있으면 VIEW intent, 없으면 런처
#   qa_act.sh stop <pkg>                        # force-stop
export PATH="/opt/homebrew/bin:$PATH"
cmd="$1"; shift
sz(){ adb shell wm size | sed 's/.*: //' | tr -d '\r'; }
case "$cmd" in
  tap)   adb shell input tap "$1" "$2";;
  swipe) adb shell input swipe "$1" "$2" "$3" "$4" "${5:-300}";;
  text)  adb shell input text "$(printf '%s' "$1" | sed 's/ /%s/g')";;
  key)   adb shell input keyevent "KEYCODE_$1";;
  launch) if [ -n "$2" ]; then adb shell am start -a android.intent.action.VIEW -d "$2" "$1";
          else adb shell monkey -p "$1" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; fi;;
  stop)  adb shell am force-stop "$1";;
  scroll)
    S=$(sz); W=${S%x*}; H=${S#*x}; CX=$((W/2)); CY=$((H/2))
    A=$((H*72/100)); B=$((H*28/100)); L=$((W*80/100)); R=$((W*20/100)); MS="${2:-400}"
    case "$1" in
      up)    adb shell input swipe $CX $B $CX $A $MS;;   # 콘텐츠 위로(아래로 스크롤)
      down)  adb shell input swipe $CX $A $CX $B $MS;;
      left)  adb shell input swipe $R $CY $L $CY $MS;;
      right) adb shell input swipe $L $CY $R $CY $MS;;
    esac;;
  *) echo "unknown: $cmd"; exit 1;;
esac
