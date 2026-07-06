#!/usr/bin/env bash
# 세션중 크래시/예외/ANR 캡처. 백그라운드로 띄울 것(run_in_background).
# usage: qa_logcat.sh <out.log>
export PATH="/opt/homebrew/bin:$PATH"
OUT="${1:-qa_logcat.log}"
adb logcat -c 2>/dev/null   # 기존 버퍼 비움(세션 시작점)
# 치명/예외/Flutter/ANR/네이티브 크래시 위주. 타임스탬프 포함 → 스텝과 시간대 매칭.
adb logcat -v time 2>/dev/null | grep --line-buffered -iE \
 "FATAL|AndroidRuntime|E/flutter|FlutterError|══╡ EXCEPTION|Unhandled|[^a-z]Exception|ANR in|Force finishing|signal [0-9]+ \(SIG|tombstone|NullPointer|OutOfMemory|StrictMode policy" \
 >> "$OUT"
