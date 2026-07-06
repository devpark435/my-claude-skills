---
name: serve-to-phone
description: Flutter 웹 프로젝트/워크트리를 빌드해 USB 연결된 폰 브라우저에 띄움(포트 8080 고정). 측정/QA 아님 — 그냥 실폰에서 보고 만지려 할 때. "폰에 띄워줘", "이 워크트리 핸드폰으로 보고싶어", "실기기에서 띄워봐" 요청 시 사용. Android(adb) 기준.
---

# 워크트리/프로젝트를 폰에 띄우기 (포트 8080)

Flutter 웹을 web-server로 서빙 + adb reverse로 USB 연결 폰 브라우저에 오픈. 앱빌드/설치 없음, CLI만.

## 언제
- "이 워크트리/프로젝트 폰에서 보고싶다", "실폰에 띄워줘" — 단순 확인/수동테스트용. (성능측정·자동QA는 `device-qa` 스킬)

## 준비 확인
- 폰 USB 연결 + USB 디버깅 ON. `adb devices` 가 'device'(unauthorized면 폰서 허용 탭).
- 띄울 **프로젝트/워크트리 경로** 확인. 여러 워크트리면 `git worktree list` 로 보여주고 사용자에게 어느 거냐 물을 것.
- 그 워크트리 빌드 가능 점검: `.env` 존재, `*.g.dart/*.freezed.dart` 생성됨, `.dart_tool` 있음. 없으면 `flutter pub get` / `dart run build_runner build --delete-conflicting-outputs` / .env 복사(main 에서).

## 실행 (한 방)
```bash
S=~/.claude/skills/serve-to-phone/scripts
bash $S/serve_to_phone.sh <project_dir>
# 포트 8080 고정. 인자: <project_dir> [port=8080] [browser_pkg] [mode]
#   browser_pkg: com.sec.android.app.sbrowser(삼성,기본,120Hz) | com.android.chrome
#   mode: profile(기본) | debug(핫리로드↑,런타임느림) | release(최적,빌드느림)
```
- 내부: 기기확인 → `adb reverse tcp:8080 tcp:8080` → `flutter run -d web-server --web-port=8080 --profile` → 빌드대기 → `am start` 로 폰 브라우저 오픈 → stayon.
- 끝나면 폰에 로드됐는지 확인 스크린샷: `adb exec-out screencap -p > shot.png` 후 Read 로 확인(권장).

## 유지/종료
- **USB 연결 + 이 serve 프로세스 유지** 해야 폰서 접속됨(reverse가 폰 localhost:8080 → 맥).
- 코드 더 고치면 web-server라 자동 핫리로드 제한적 → 폰 새로고침 or 재서빙.
- 종료: `pkill -f "flutter_tools.snapshot run"` + `adb reverse --remove-all` + `adb shell svc power stayon false`.
- 다른 워크트리로 교체: 종료 후 같은 스크립트에 다른 경로로 재실행.

## 주의
- 포트 8080 고정 — 이미 8080 점유시 충돌. 그때만 2번째 인자로 포트 바꿀 것.
- 삼성 기본 브라우저(삼성 인터넷)는 웹 120Hz 지원, 크롬은 60Hz 캡(렌더 느낌 다름).
- 측정/자동조작 필요하면 이 스킬 말고 `device-qa`.
