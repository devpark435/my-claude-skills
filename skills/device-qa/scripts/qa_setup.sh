#!/usr/bin/env bash
# 기기/앱/화면 확인. usage: qa_setup.sh [pkg]
export PATH="/opt/homebrew/bin:$PATH"
adb devices | grep -qw device || { echo "NO_DEVICE (USB 연결 + 디버깅 허용 확인)"; exit 1; }
SER=$(adb devices | awk '/\tdevice$/{print $1; exit}')
echo "device=$SER"
echo "model=$(adb shell getprop ro.product.model | tr -d '\r')"
SIZE=$(adb shell wm size | sed 's/.*: //' | tr -d '\r'); echo "size=$SIZE"
echo "density=$(adb shell wm density | sed 's/.*: //' | tr -d '\r')"
FG=$(adb shell dumpsys activity activities 2>/dev/null | grep -m1 -oE "[a-zA-Z0-9_.]+/[a-zA-Z0-9_.]+" | tr -d '\r')
echo "foreground=$FG"
if [ -n "$1" ]; then
  echo "target_pkg=$1"
  adb shell pidof "$1" >/dev/null 2>&1 && echo "running=yes" || echo "running=no"
fi
