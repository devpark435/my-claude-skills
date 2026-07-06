# 실기기 스크롤 성능 측정 툴킷

실폰(또는 임의 기기)에 USB로 붙어, **앱/웹을 자동으로 스크롤시키며 프레임 성능(jank/120fps 적합도)을 수치로 측정**하는 방법 정리.
KPharm 웹(Flutter Web)에서 만들었고, 네이티브 앱에도 적용 가능. (작성 2026-06-17)

---

## 0. TL;DR

- **목적**: "스크롤이 끊기나?"를 사람 손이 아니라 자동으로, 화면별·프레임별 수치로 판정.
- **핵심 지표**: 프레임당 `work = build(UI/Dart) + raster(GPU)` ms. 이게 **주사율과 무관**해서 60Hz 기기로 재도 120fps(예산 8.33ms) 적합 여부를 안다.
- **구성**: ①앱 안에 프레임수집 하네스 ②기기에 USB로 붙어 자동 스크롤 구동 ③결과를 PC로 모아 집계.
- **결론 사례**: 우리 웹은 크롬(안드)에선 60fps 캡, **삼성 인터넷에선 진짜 120fps**. 화면별 드랍 원인까지 추적됨(트렌딩 칩=build, 랭킹=raster 등).

---

## 1. 어떻게 동작하나 (아키텍처)

```
[PC(맥)]                                  [실폰 USB]
 flutter web-server :8099  ──adb reverse──▶ 폰 브라우저가 localhost:8099 로 우리 앱 로드
 sink.py :9009  ◀──adb reverse──  앱 내 하네스가 프레임통계를 beacon 으로 전송
 cdp_*.mjs (CDP)  ──adb forward──▶ 폰 브라우저 제어(reload / 스크롤 트리거 / bringToFront)
 aggregate_*.py                            결과 JSON 집계 → 표/판정
```

3조각:

### (A) 인앱 프레임 수집 하네스 — `harness/scroll_profiler.dart`
- `SchedulerBinding.addTimingsCallback` 로 프레임마다 `buildDuration`(UI스레드), `rasterDuration`(GPU스레드), `totalSpan` 수집.
- 부팅 4초 후 화면 순회(홈→트렌딩→지도)하며 각 스크롤을 결정적 `animateTo` 왕복 → 프레임 모음 → 통계.
- 산출: fps, work(build+raster) p50/p95/p99/max, **120fps 적합%**(work≤8.33ms 비율), 60fps 적합%, **드랍 케이스 개별 추적**(8.33ms 초과 프레임의 원인 build/raster + 스크롤 내 위치).
- 웹은 `print()`가 터미널로 안 와서 결과를 `sendBeacon('http://localhost:9009/')` 로 PC sink 에 보냄.
- 컴파일 게이트: `--dart-define=PERFTEST=true` + 비릴리즈에서만 동작(프로덕션 무영향).

### (B) PC 측 수집/구동 — `scripts/`
- `sink.py <out.log>` : :9009 HTTP 서버, beacon 받아 로그파일에 append.
- `cdp_phone3.mjs <port> <runs> <sink>` : 폰 브라우저를 CDP로 N회 reload(=N런), 각 런 완료(`__PERF_DONE__`)까지 대기. **`Page.bringToFront` 포함**(백그라운드 탭 0x0 방지). 런마다 타겟 재탐색+ws 재연결(견고).
- `cdp_drive.mjs` : 데스크 크롬용(뷰포트 에뮬레이션 `setDeviceMetricsOverride` 포함). **실폰엔 쓰지 말 것**(실뷰포트 써야 함).
- `aggregate_phone.py <log>` : 화면별 fps/work/적합%(120·60) 표.
- `aggregate_fit.py <log>` : 120fps 적합도 표(work 기반).
- `aggregate_drops.py <log>` : **화면별 드랍 케이스 추적**(개수·원인 build/raster·심각도·스크롤 위치·최악 샘플).

### (C) adb 라우팅
- `adb reverse tcp:8099 tcp:8099` : 폰 localhost:8099 → PC serve.
- `adb reverse tcp:9009 tcp:9009` : 폰 beacon → PC sink.
- `adb forward tcp:9223 localabstract:<devtools소켓>` : PC → 폰 브라우저 CDP.
  - 크롬 소켓 = `chrome_devtools_remote`, **삼성 인터넷 = `Terrace_devtools_remote`**.

---

## 2. 웹 측정 절차 (현재 우리가 한 것)

**1회 준비**
```bash
brew install android-platform-tools        # adb
# 폰: 설정→휴대폰정보→빌드번호 7탭(개발자옵션)→USB디버깅 ON
# 120Hz: 설정→디스플레이→주사율/모션스무스 적응형(120)
```

**측정**
```bash
adb devices                                 # 'device' 확인(unauthorized면 폰서 허용 탭)
adb shell svc power stayon usb              # 측정중 화면 안 꺼지게

# PC: 프로파일 빌드 서빙(브라우저 안 띄움)
fvm flutter run -d web-server --web-port=8099 --profile --dart-define=PERFTEST=true
adb reverse tcp:8099 tcp:8099
adb reverse tcp:9009 tcp:9009
python3 scripts/sink.py perf.log           # 결과 수집

# 폰 브라우저로 앱 열기(삼성 인터넷 예)
adb shell am start -a android.intent.action.VIEW -d "http://localhost:8099" com.sec.android.app.sbrowser
# devtools 소켓 확인 후 forward
adb shell cat /proc/net/unix | grep devtools     # Terrace_devtools_remote 확인
adb forward tcp:9223 localabstract:Terrace_devtools_remote

# 자동 구동(10런)
node scripts/cdp_phone3.mjs 9223 10 perf.log
python3 scripts/aggregate_drops.py perf.log      # 결과
```

**정리**
```bash
adb shell svc power stayon false
adb reverse --remove-all; adb forward --remove-all
```

---

## 3. 네이티브 앱에 적용하려면 (필요한 것)

웹의 CDP만 브라우저 전용. 네이티브는 **더 좋은 공식 도구**가 있음. 갈아끼우는 부분:

| 조각 | 웹(현재) | 네이티브 Flutter |
|---|---|---|
| 프레임수집 | scroll_profiler.dart + beacon | **동일 하네스 그대로**(엔진레벨). 단 beacon(dart:html) → `print()`/파일/VM서비스로 교체(네이티브는 print가 터미널로 옴) |
| 자동 스크롤 | CDP reload + animateTo | **`integration_test` + `flutter drive`**(공식) 또는 `adb shell input swipe`(범용) |
| 프레임 지표 | beacon JSON | `flutter drive --profile` 가 **타임라인 JSON 자동 산출**(build/raster) / VM Service 프로토콜 / **`adb shell dumpsys gfxinfo <패키지>`**(OS레벨, 소스 없어도) |
| 기기 제어 | adb forward + CDP | adb(input/gfxinfo) / VM Service / flutter_driver |

**네이티브에서 필요한 것**
1. **앱 소스 있으면(우리 앱)**: `integration_test` 패키지로 시나리오 작성(`find.byKey`/`scrollUntilVisible`) → `flutter drive --profile --driver=... --target=...` → 타임라인 요약(`*.timeline_summary.json`)에 `frame_build_times`/`frame_rasterizer_times` 들어옴. **scroll_profiler 하네스 없이도** 공식 경로로 측정 가능.
2. **소스 없는 임의 앱(블랙박스)**: `adb shell input swipe`(스크롤 주입) + `adb shell dumpsys gfxinfo <pkg> reset/덤프`(프레임 jank% , 90/95/99 percentile, deadline miss). 화면 찾기는 `uiautomator dump`(요소 좌표) 또는 스크린샷-비전.
3. **시나리오 기반 E2E**(로그인→검색→스크롤→사용 등): `adb input` + 스크린샷 확인 루프, 또는 **Maestro**(YAML 시나리오 `tapOn/scroll/assertVisible`) — 반복실행에 최적.

**iOS**
- 가능하나 마찰↑: **Mac + Xcode 필수**, 실기기는 **코드사이닝/개발자계정** 필요(WebDriverAgent/테스트러너 설치 위해).
- 도구: **XCUITest**(공식), **Appium**, **Maestro**(iOS 지원), **idb**(adb 비슷: `idb ui tap/swipe/screenshot`).
- 시뮬레이터는 사이닝 없이 쉽지만 **맥 CPU로 돌아 실하드웨어 성능 아님**(성능판정엔 무효, 기능테스트만).
- 프레임지표: Instruments/MetricKit, Flutter FrameTiming 하네스는 동일 작동.

---

## 4. 지표 읽는 법

- **work = build + raster (ms/프레임)**. 주사율 무관 = 어느 기기서 재든 그 값이 그 프레임의 비용.
- 예산: **120fps = 8.33ms**, 60fps = 16.67ms, 심각 = 33ms.
- **적합%@120** = work ≤ 8.33ms 인 프레임 비율. 높을수록 120fps 매끄러움.
- **fps**: 실제 측정 프레임/시간. 패널 120Hz인데 fps~60이면 = 브라우저 60Hz 페이싱 or work과중으로 절반 vsync.
- **드랍 원인**: build 우세 = Dart 위젯빌드(약CPU서 폭증), raster 우세 = GPU 그리기(블러/SVG/CJK글리프/이미지).
- **드랍 위치(frac)**: 초반 집중 = 콜드(첫 진입 빌드·래스터), 전구간 = 지속 재발(진짜 최적화 대상).

---

## 5. 함정/교훈 (꼭 기억)

1. **데스크 측정 ≠ 폰 성능.** CDP 모바일 에뮬은 뷰포트·dpr만 바꾸고 CPU/GPU는 PC. 폰은 work 2배 이상. **실기기로 재야 진짜.**
2. **브라우저가 결과 가른다.** 안드 크롬 = 웹 60Hz 캡(크로미움 제한). **삼성 인터넷 = 진짜 120Hz.** 같은 앱·폰, 브라우저만 바꿔 fps 56→113.
3. **백그라운드 탭 = viewport 0x0** → 렌더정지 → 측정 타임아웃. 드라이버에 `Page.bringToFront` 필수. am-start 반복하면 탭 쌓여 엉뚱한(백그라운드) 탭 타겟됨.
4. **adb reverse(폰→PC)는 USB 리셋 시 잘 끊김.** 런마다 재설정 권장. forward(PC→폰)는 비교적 안정.
5. **uncapped-vsync(`--disable-gpu-vsync`) 120Hz 프록시는 신뢰 말 것.** 모든 비용 과장 + 일부 경로(toImageSync) 행. 120fps 판정은 **work-time 지표**로.
6. **합성 마이크로벤치(toImageSync 단가 측정)는 부정확** — surface 할당이 신호를 삼킴. 실프레임 FrameTiming(work) 지표를 신뢰.
7. 측정중 폰 화면 꺼지면 렌더 멈춤 → `svc power stayon usb`.

---

## 6. 스킬화 (어느 프로젝트서든) — 다음 섹션 참고
→ `SKILL_NOTES.md`
