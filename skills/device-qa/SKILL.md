---
name: device-qa
description: 실기기(USB)에 붙어 앱/웹을 자동 조작하며 QA. 주어진 유저 시나리오 실행, 또는 네비게이션을 자율 탐색해 시나리오 자가생성·실행. 진행중 오류(크래시/예외/블랭크/무반응) 캐치 + 성능 측정, 끝나면 보고서. "실폰 시나리오 테스트", "앱 자동 QA", "유저플로우 돌려봐", "화면 탐색하며 버그 찾아" 요청 시 사용. Android(adb) 주력, iOS(idb/XCUITest)는 셋업 추가.
---

# 실기기 QA 에이전트

USB 연결된 실기기에서 앱/웹을 **직접 조작(탭/스와이프/입력)** 하며 QA. 화면을 스크린샷으로 보고 판단→동작→검증하는 에이전트 루프.

## 핵심 전제 (먼저 읽기)
- **Flutter 앱은 uiautomator UI트리가 빈약**(단일 캔버스로 렌더). → 요소 찾기는 **스크린샷 비전(Read 로 png 판독)이 주력**. xml 은 보조.
- 그래서 단계마다 `screencap→판독→input→재캡처→검증` = 느리지만 견고. 빠른 반복은 소스있는 앱이면 `integration_test`/Maestro 권장(아래).
- **좌표는 screencap png 픽셀 좌표 = adb input 좌표** 동일. 비전으로 요소 중심 좌표 읽어 그대로 탭.
- 100% 무결 아님. 타이밍/무반응 변수 → 검증 루프로 잡음. 막히면 사용자에게.

## 모드 (시작 시 사용자에게 확인 or 추론)
1. **scripted** — 사용자가 시나리오 제공(말/리스트). 그대로 실행·검증.
2. **autonomous** — 네비게이션 자율 탐색 → 화면맵 구축 → 유저 시나리오 자가생성 → 실행.
3. **hybrid** — 사용자가 영역/목표만("쿠폰 흐름 위주") → 세부 단계는 내가 채움.

## 대상 구분 (웹/네이티브 — 한 스킬로 둘 다)
핵심 루프(스크린샷→비전→input→검증→logcat)·오류캐치·보고서는 **웹/앱 공통**. 다른 건 2개뿐:
- **실행 대상**: 웹 = 브라우저 pkg(`com.android.chrome`/`com.sec.android.app.sbrowser`) + URL (+ 서빙시 `adb reverse`, `references/GUIDE.md`). 네이티브 = 앱 pkg 직접 launch.
- **성능 배관**: 웹 = CDP reload + beacon(sink/cdp_phone3/aggregate). 네이티브 = `flutter drive --profile`(타임라인) / `adb shell dumpsys gfxinfo <pkg>` / VM Service.
나머지는 동일하게 진행.

## 0. 준비
```bash
S=~/.claude/skills/device-qa/scripts
bash $S/qa_setup.sh [pkg]        # device/model/size/foreground 확인. NO_DEVICE면 USB+디버깅 안내
```
- `adb devices` unauthorized → 폰서 "USB 디버깅 허용" 탭 안내.
- 작업폴더 정함(스크린샷/로그 저장): 예 `$CLAUDE_JOB_DIR/tmp/qa` 또는 프로젝트 tmp.
- 화면 안꺼지게: `adb shell svc power stayon usb`.
- **오류 캐치용 logcat 백그라운드로 시작**(필수):
  ```bash
  bash $S/qa_logcat.sh <dir>/logcat.log   # run_in_background:true 로 띄울 것
  ```
- 대상 앱 실행: `bash $S/qa_act.sh launch <pkg> [url]`. (웹이면 브라우저 pkg + url; GUIDE 의 web-server/adb reverse 셋업 참고)
- (성능도 볼거면) harness/scroll_profiler.dart + sink/cdp 경로 = `references` 의 GUIDE 방식.

## 1. 에이전트 루프 (모든 동작의 단위)
각 스텝:
1. `bash $S/qa_snap.sh step_NN <dir>` → 반환된 png 를 **Read 로 본다**.
2. 목표 요소/상태 판단(비전). 좌표 추출.
3. `bash $S/qa_act.sh tap X Y` (또는 swipe/text/scroll/key).
4. 대기(0.5~1.5s, 화면 전환 무거우면 더). 재캡처.
5. **검증**: 화면이 의도대로 바뀜? 아래 "오류 캐치" 체크. 스텝 결과 기록(통과/실패/오류).
6. logcat.log **tail 확인**(새 에러 라인? 타임스탬프로 이 스텝과 매칭).

기록은 메모리에 누적(스텝 리스트: 화면, 동작, 결과, 스크린샷 경로, 발견오류).

## 2. 오류 캐치 (매 스텝 점검)
- **크래시/ANR**: 앱 pid 사라짐(`adb shell pidof <pkg>` 빔) / logcat `FATAL`,`signal`,`ANR in`,`tombstone`.
- **Flutter 예외**: logcat `E/flutter`,`══╡ EXCEPTION`,`Unhandled`.
- **시각 오류**(스크린샷 판독): 에러 다이얼로그/토스트, 블랭크·흰화면, "오류/에러/실패/Error/문제" 텍스트, 깨진 이미지, 무한 로딩(스피너 고정).
- **기능 오류**: 탭 무반응(전후 화면 동일), 네비 막다른길, 뒤로가기 루프, 잘못된 화면 진입.
- **성능 jank**(측정 모드): work>16.67ms 프레임/스파이크(aggregate_*.py).
각 오류 → {화면, 스크린샷, logcat 스니펫, 재현 스텝, 추정원인} 기록.

## 3. autonomous 탐색 전략
- 현재 화면에서 **탭 가능한 요소 열거**(비전: 버튼/탭바/리스트/아이콘). 
- 화면 식별 = 보이는 텍스트/레이아웃 해시(중복 방문 회피). 방문 집합 유지.
- DFS/BFS: 각 요소 탭→결과 화면 기록→`key BACK`로 복귀→다음. **깊이/스텝 상한 설정**(예 깊이4, 총 60스텝) — 무한루프 방지.
- 막다른길/반복 감지하면 백트랙. 권한/로그인/결제 만나면 표시하고 우회 or 사용자 요청.
- 그래프 완성 후: **유저 시나리오 자가생성**(각 탭 방문, 리스트 진입, 폼 작성·제출, 핵심 플로우 도달) → scripted 처럼 실행·검증.
- **상한 도달/미탐색 영역은 보고서에 명시**(조용히 빼지 말 것).

## 4. scripted 실행
- 사용자 시나리오를 스텝으로 분해. 각 스텝 = 루프(1). 
- 입력값 필요시 사용자에게(로그인/검색어 등) or 합리적 더미.
- 단계 실패해도 가능하면 계속(이후 단계 독립이면) + 실패 기록. 치명(크래시)이면 재기동 후 다음 시나리오.

## 5. 보고서
- `templates/report.md` 양식으로 작성. 사용자 지정 경로 or 데스크탑/프로젝트에 .md 저장.
- 포함: 요약, 시나리오 결과표, **오류 상세(스크린샷+로그+재현)**, 화면맵(자율시), 성능부록, 미탐색/한계.
- 스크린샷은 경로로 참조(보고서 옆 폴더).

## 6. 정리
```bash
adb shell svc power stayon false
# logcat 백그라운드 종료(TaskStop), 측정 셋업 썼으면 adb reverse/forward --remove-all
```

## 도구
- `scripts/qa_setup.sh` `qa_logcat.sh` `qa_snap.sh` `qa_act.sh` — 기기제어.
- `scripts/sink.py cdp_phone3.mjs aggregate_*.py` + `harness/scroll_profiler.dart` — 성능측정(웹). 상세 = `references/GUIDE.md`.

## iOS
- 가능하나 Mac+Xcode 필수, 실기기는 코드사이닝/개발자계정(WebDriverAgent). 도구: **idb**(`idb ui tap/swipe/screenshot` = qa_act 대응), XCUITest/Appium/Maestro. 시뮬레이터는 성능판정 무효(맥CPU). 비전 루프는 idb screenshot 으로 동일.

## 한계 (사용자에게 미리)
- 기기 USB 연결·(iOS)사이닝·로그인/결제 개입은 사람 몫.
- Flutter 비전 의존이라 단계마다 느림. 좌표 타이밍 변수로 가끔 재시도 필요.
- 정식 견고 경로(소스 있을 때): integration_test(`flutter drive`) / Maestro YAML — 스킬이 스캐폴딩 도울 수 있음.
