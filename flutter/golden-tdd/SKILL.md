---
name: flutter-golden-tdd
description: Use when writing Flutter widget or screen-level golden tests, setting up matchesGoldenFile infrastructure, fixing □ box font rendering in test output, stabilizing golden PNGs for CI, or testing widgets with multiple enum states. Also triggers when asked to add golden tests to a specific screen (HomeScreen, DetailScreen, etc).
---

# Flutter Golden TDD

## Overview

위젯 상태 enum 이 늘어나 텍스트 expect 만으로 회귀를 못 잡을 때 golden test 로 픽셀 단위 UI 고정. 핵심 3층 안전망: 텍스트 의미론 → 콜백 결선 → 골든 시각 회귀.

## 필수 선결 조건 — 폰트 □ 박스 문제

Flutter 테스트 환경 기본 폰트는 **Ahem** (디버그용 검은 사각형). 골든은 픽셀 비교라서 글자가 전부 □ 로 찍힘.

### 해결: `flutter_test_config.dart` (전역 권장)

```dart
// test/flutter_test_config.dart
import 'dart:async';
import 'package:golden_toolkit/golden_toolkit.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();
  await testMain();
}
```

파일 단위 `main()` 에 넣어도 되지만 빠뜨리는 사고 원천 차단은 전역 방식만 됨.

**의존성:**
```yaml
dev_dependencies:
  golden_toolkit: ^0.x.x   # loadAppFonts() 한 줄을 위해 추가
```

## 폴더 구조

```
test/
├── flutter_test_config.dart        # 전역 loadAppFonts()
├── helpers/
│   ├── pump_app.dart               # ProviderScope + MaterialApp 래퍼
│   ├── make_container.dart         # ProviderContainer + tearDown
│   └── dio_mock.dart               # Dio + DioAdapter 페어
└── presentation/<feature>/
    └── widget/
        ├── card_test.dart
        └── goldens/                # PNG 파일 위치
            ├── card_state_a.png
            └── card_state_b.png
```

## 표준 헬퍼 3종

### pumpApp — 위젯 단위

```dart
Widget pumpApp({
  required Widget child,
  List<Override> overrides = const [],
  ThemeData? theme,
  Size? screenSize,
}) {
  Widget app = MaterialApp(
    theme: theme,
    debugShowCheckedModeBanner: false,
    home: child,
  );
  if (screenSize != null) {
    app = MediaQuery(data: MediaQueryData(size: screenSize), child: app);
  }
  return ProviderScope(overrides: overrides, child: app);
}
```

`screenSize` 는 **반드시 명시** — 골든은 픽셀 비교라 해상도 흔들리면 무조건 깨짐. `Size(390, 720)` 하나로 통일.

### makeContainer — 비위젯 Riverpod 단위

```dart
ProviderContainer makeContainer({List<Override> overrides = const []}) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);  // 누수 차단
  return container;
}
```

### makeDioWithMock — Retrofit + Dio

```dart
({Dio dio, DioAdapter adapter}) makeDioWithMock({BaseOptions? options}) {
  final dio = Dio(options);
  final adapter = DioAdapter(dio: dio);
  return (dio: dio, adapter: adapter);
}
```

Dio 인스턴스 실제 사용 → 인터셉터/직렬화 경로 실코드 탐. 응답만 가짜.

## 핵심 패턴 — enum.values 루프

```dart
Future<void> main() async {
  await loadAppFonts();  // flutter_test_config.dart 없으면 여기에

  group('ReservationCard — state matrix', () {
    // 1층: 의미론 검증
    testWidgets('upcomingWaiting — Start 버튼만 노출', (tester) async {
      await tester.pumpWidget(pumpApp(
        screenSize: const Size(390, 720),
        child: _wrap(_build(CardState.upcomingWaiting)),
      ));
      expect(find.text('Start service'), findsOneWidget);
      expect(find.text('Request surcharge'), findsNothing);
    });

    // 2층: 콜백 결선
    testWidgets('ongoingEndOnly — End 탭 시 콜백 1회', (tester) async {
      var taps = 0;
      await tester.pumpWidget(pumpApp(
        screenSize: const Size(390, 720),
        child: ReservationCard(
          state: CardState.ongoingEndOnly,
          onPrimaryAction: () => taps++,
          // ...
        ),
      ));
      await tester.tap(find.text('End service'));
      await tester.pump();
      expect(taps, 1);
    });

    // 3층: 골든 — enum 전수 자동 커버
    for (final state in CardState.values) {
      testWidgets('golden — card_${state.name}', (tester) async {
        await tester.pumpWidget(pumpApp(
          screenSize: const Size(390, 720),
          child: _wrap(_build(state)),
        ));
        await expectLater(
          find.byType(ReservationCard),
          matchesGoldenFile('goldens/card_${state.name}.png'),
        );
      });
    }
  });
}
```

`enum.values` 루프 핵심: **enum 케이스 추가 시 골든 자동 1장 추가**. 작성자가 잊어도 컴파일러가 잊지 않음.

## 화면 단위 골든 — Provider override

```dart
Future<void> _pump(WidgetTester tester, HomeRes data) async {
  await tester.pumpWidget(pumpApp(
    screenSize: const Size(390, 844),
    overrides: [
      homeProvider(null).overrideWith((ref) => Future.value(data)),
    ],
    child: const HomeScreen(),
  ));
  await tester.pumpAndSettle();  // loading → data 전환 완료 대기
}
```

- `Future.value(data)` → `AsyncValue` 즉시 해소, 네트워크 흔들림 0
- `pumpAndSettle()` 빠뜨리면 로딩 인디케이터가 찍힌 골든 생성됨

## 명령어

```bash
# 신규 생성 (첫 실행은 --update-goldens 필수)
flutter test --update-goldens test/presentation/.../card_test.dart

# 회귀 검증
flutter test test/presentation/.../card_test.dart

# 실패 diff 위치
build/test/failures/<test>.<name>.<expected|actual|diff>.png
```

**`--update-goldens` 는 의도된 디자인 변경일 때만.** 회귀 잡는 PR 에서 갱신 = 회귀가 정답이 됨.

## 커밋 컨벤션

```
feat(home): 카드 상태별 분기 + 골든 11종 추가

[component/reservation_card]
- CardState enum 11종 분기
- 상태별 버튼/색 토큰 매핑

[TDD-Golden]
- test/presentation/home/widget/reservation_card_test.dart
- test/presentation/home/widget/goldens/reservation_card_*.png (11장)
```

feat + test/golden 한 커밋에 묶기 → atomic revert 보장 + `[TDD-Golden]` 섹션으로 진척도 가시화.

## 언제 골든 쓰고 언제 텍스트 expect 쓰나

| 대상 | 권장 |
|------|------|
| 카드 / 시트 / 다이얼로그 / 헤더 | 골든 ROI 최고 |
| enum 상태 11+ 가지 위젯 | 골든 필수 |
| 단순 폼 인풋 | 텍스트 expect 충분 |
| 색 토큰 / 정렬 회귀 | 골든만 잡을 수 있음 |

## 회귀 처리 흐름 (TDD)

1. 회귀 케이스 골든 없으면 먼저 생성 (Red — 빨강 확인 필수)
2. 구현 수정 (Green)
3. 골든 통과 → 동일 회귀 영구 차단

## 에셋/아이콘/이미지 깨짐 처리

### 네트워크 이미지 (`Image.network`, `CachedNetworkImage`)

테스트 환경에서 네트워크 요청 차단 → 빈 박스 또는 에러 위젯으로 찍힘.

```dart
// test/helpers/pump_app.dart 상단에 추가
import 'dart:io';

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (_, __, ___) => true;
  }
}

// flutter_test_config.dart 에 추가
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  HttpOverrides.global = _FakeHttpOverrides();
  await loadAppFonts();
  await testMain();
}
```

또는 위젯 자체에서 네트워크 이미지를 `Image.asset` placeholder 로 교체하는 `overrideWith` 패턴 사용.

### SVG 아이콘 (`flutter_svg`)

`flutter_svg` 의 `SvgPicture.asset` 은 일반적으로 작동. `SvgPicture.network` 는 네트워크 이미지와 동일 문제.

커스텀 아이콘 폰트(`.ttf` 기반 아이콘)는 `pubspec.yaml` 에 폰트 선언 필수 — 없으면 □ 박스.

```yaml
# pubspec.yaml
flutter:
  fonts:
    - family: CustomIcons
      fonts:
        - asset: assets/fonts/custom_icons.ttf
```

선언 후 `loadAppFonts()` 가 자동으로 로드.

### CI vs 로컬 플랫폼 diff (anti-aliasing)

macOS(로컬) ↔ Linux(CI) 간 렌더링 엔진 차이로 동일 코드라도 1~2px 차이 발생. 전역 tolerance 설정으로 흡수:

```dart
// test/flutter_test_config.dart
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();
  goldenFileComparator = LocalFileComparator(
    Uri.file('${Directory.current.path}/test'),
  );
  // 허용 오차 0.5% — 텍스트/색 회귀는 잡되 anti-aliasing noise 흡수
  // 값 올릴수록 회귀 검출력 약해짐. 1% 초과 권장 안 함.
  (goldenFileComparator as LocalFileComparator).tolerance;
  await testMain();
}
```

또는 CI 에서 골든 생성 후 커밋하는 방식 (CI 플랫폼 기준으로 골든 고정):

```yaml
# .github/workflows/test.yml
- name: Update goldens (CI 기준)
  run: flutter test --update-goldens
  # 첫 세팅 또는 의도된 변경 시에만 실행
```

CI 플랫폼 고정 방식이 가장 안정적. tolerance 는 보조 수단.

## 흔한 실수

| 실수 | 결과 | 수정 |
|------|------|------|
| `loadAppFonts()` 빠뜨림 | □ 박스 골든이 기준선으로 머지됨 | `flutter_test_config.dart` 전역 설정 |
| 커스텀 아이콘 폰트 pubspec 미선언 | 아이콘 □ 박스 | `pubspec.yaml` fonts 섹션에 추가 |
| `screenSize` 미지정 | 환경마다 골든 깨짐 | `Size(390, 720)` 고정 |
| `pumpAndSettle()` 빠뜨림 | 로딩 화면이 골든으로 고정됨 | async provider 있으면 필수 |
| 네트워크 이미지 mock 없음 | 이미지 영역 빈 박스로 찍힘 | `HttpOverrides` 또는 asset fallback |
| CI vs 로컬 tolerance 미설정 | 로컬 통과, CI 깨짐 | CI 기준 골든 고정 또는 tolerance 적용 |
| 회귀 PR 에서 `--update-goldens` | 회귀가 새 기준선이 됨 | 의도된 변경에만 사용 |
| 골든 남발 | PR 마다 수십 장 diff 리뷰 대기 | 복잡 위젯에만 적용 |
