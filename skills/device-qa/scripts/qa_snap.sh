#!/usr/bin/env bash
# 스크린샷(+UI트리 시도). usage: qa_snap.sh <label> <dir>
# Flutter 앱은 uiautomator 트리가 빈약할 수 있음(png 가 주력, Claude 가 비전으로 판독).
export PATH="/opt/homebrew/bin:$PATH"
LABEL="${1:-snap}"; DIR="${2:-.}"; mkdir -p "$DIR"
adb exec-out screencap -p > "$DIR/$LABEL.png"
adb shell uiautomator dump /sdcard/_uid.xml >/dev/null 2>&1 \
  && adb pull /sdcard/_uid.xml "$DIR/$LABEL.xml" >/dev/null 2>&1
echo "$DIR/$LABEL.png"
