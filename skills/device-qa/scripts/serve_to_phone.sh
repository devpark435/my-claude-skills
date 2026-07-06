#!/usr/bin/env bash
# Flutter 웹 워크트리/프로젝트를 폰 브라우저에 띄움(측정 아님, 그냥 보기).
# usage: serve_to_phone.sh <project_dir> [port] [browser_pkg] [mode]
#   browser_pkg: com.sec.android.app.sbrowser(삼성,기본) | com.android.chrome
#   mode: profile(기본) | debug | release
# 끄기: pkill -f "flutter_tools.snapshot run"; adb reverse --remove-all
set -e
export PATH="/opt/homebrew/bin:$PATH"
DIR="${1:?project_dir 필요}"; PORT="${2:-8080}"; PKG="${3:-com.sec.android.app.sbrowser}"; MODE="${4:-profile}"
FVM=$(command -v fvm >/dev/null 2>&1 && echo "fvm " || echo "")

adb devices | grep -qw device || { echo "NO_DEVICE (USB+디버깅 확인)"; exit 1; }
adb reverse tcp:$PORT tcp:$PORT
adb shell svc power stayon usb >/dev/null 2>&1

LOG="${TMPDIR:-/tmp}/serve_to_phone_$PORT.log"; : > "$LOG"
( cd "$DIR" && ${FVM}flutter run -d web-server --web-port=$PORT --$MODE > "$LOG" 2>&1 ) &
echo "serve pid $! (log: $LOG)"
echo -n "빌드 대기"
for i in $(seq 1 120); do
  grep -qE "Flutter run key commands" "$LOG" && break
  grep -qE "Failed|Error:|Exception" "$LOG" && { echo " 실패"; tail -5 "$LOG"; exit 1; }
  echo -n "."; sleep 2
done
echo " 완료"
curl -s -o /dev/null -w "mac localhost:$PORT -> %{http_code}\n" http://localhost:$PORT/ || true
adb shell am start -a android.intent.action.VIEW -d "http://localhost:$PORT" "$PKG" >/dev/null 2>&1
echo "폰($PKG)에서 http://localhost:$PORT 열림. USB 연결+이 serve 유지할 것."
