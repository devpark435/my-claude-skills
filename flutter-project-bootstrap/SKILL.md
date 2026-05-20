---
name: flutter-project-bootstrap
description: Use when starting a new Flutter project from scratch — scaffolds Clean Architecture folder structure, installs standard packages (Riverpod, go_router, Dio, Retrofit, freezed), creates base files (router, Dio provider, constants), and generates CLAUDE.md. Skip CI/CD setup.
---

# Flutter Project Bootstrap

회사 표준 Flutter 프로젝트 초기 세팅. 실행 순서대로 따를 것.

## 표준 스택

| 항목 | 선택 |
|------|------|
| 상태관리 | `flutter_riverpod` + `riverpod_annotation` + `riverpod_generator` |
| 라우팅 | `go_router` |
| 네트워크 | `dio` + `retrofit` + `retrofit_generator` |
| 직렬화 | `freezed` + `json_serializable` |
| 코드생성 | `build_runner` |
| 로컬저장 | 프로젝트마다 결정 — 초기 세팅 제외 |

---

## Step 1 — Flutter 프로젝트 생성

```bash
flutter create <project_name> --org <bundle_prefix>
# 예: flutter create howlpot --org com.company
cd <project_name>
```

---

## Step 2 — 패키지 설치

```bash
# 런타임
flutter pub add \
  flutter_riverpod \
  riverpod_annotation \
  go_router \
  dio \
  retrofit \
  freezed_annotation \
  json_annotation

# 개발 전용
flutter pub add --dev \
  build_runner \
  riverpod_generator \
  retrofit_generator \
  freezed \
  json_serializable \
  custom_lint \
  riverpod_lint
```

---

## Step 3 — 폴더 구조 생성

```bash
mkdir -p lib/core/{constant,provider,router,util,component}
mkdir -p lib/domain/{model,repository,usecase}
mkdir -p lib/data/{repository_impl,remote,local}
mkdir -p lib/presentation
mkdir -p test/helpers
```

**최종 구조:**
```
lib/
  core/
    constant/       # AppColor, AppTextStyles, AppSizes 등
    provider/       # Dio, SharedPrefs 등 글로벌 provider
    router/         # GoRouter 설정
    util/           # 유틸 함수
    component/      # 공용 위젯
  domain/
    model/          # freezed 데이터 모델
    repository/     # abstract 인터페이스
    usecase/        # 복잡한 비즈니스 로직 (단순하면 생략)
  data/
    repository_impl/ # Repository 구현체
    remote/         # Retrofit 클라이언트
    local/          # 로컬 저장소 (프로젝트마다 추가)
  presentation/
    <feature>/      # 기능별 폴더
      screen/
      widget/
      provider/     # 해당 기능 전용 provider
  main.dart
```

**기능 폴더 예시:**
```
presentation/
  auth/
    screen/
      login_screen.dart
      signup_screen.dart
    widget/
      login_button.dart
    provider/
      auth_provider.dart
  home/
    screen/
      home_screen.dart
    widget/
```

---

## Step 4 — 베이스 파일 생성

### `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';

void main() {
  runApp(const ProviderScope(child: App()));
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

### `lib/core/router/app_router.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'app_router_enum.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRouter.home.path,
    routes: [
      // 라우트 추가
    ],
  );
});
```

### `lib/core/router/app_router_enum.dart`

```dart
enum AppRouter {
  home(path: '/'),
  ;

  const AppRouter({required this.path});
  final String path;
  String get name => toString().split('.').last;
}
```

### `lib/core/provider/dio_provider.dart`

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
      validateStatus: (status) => status != null && status < 500,
    ),
  );
  // dio.interceptors.add(CustomInterceptor(ref: ref));
  return dio;
});
```

### `lib/core/constant/app_color.dart`

```dart
import 'package:flutter/material.dart';

class AppColor {
  AppColor._();
  // 프로젝트 컬러 토큰 추가
  static const primary = Color(0xFF000000);
  static const background = Color(0xFFFFFFFF);
}
```

### `lib/core/constant/app_text_styles.dart`

```dart
import 'package:flutter/material.dart';
import 'app_color.dart';

class AppTextStyles {
  AppTextStyles._();
  // 프로젝트 텍스트 토큰 추가
}
```

---

## Step 5 — build_runner 설정

`build.yaml` 프로젝트 루트에 생성:

```yaml
targets:
  $default:
    builders:
      riverpod_generator:
        options:
          build_extensions: {".dart": [".g.dart"]}
```

`.gitignore` 에 추가:
```
*.g.dart
*.freezed.dart
```

---

## Step 6 — CLAUDE.md 생성

프로젝트 루트에 `CLAUDE.md` 생성. 아래 내용을 프로젝트에 맞게 채울 것:

```markdown
# CLAUDE.md — <프로젝트명>

## 프로젝트 개요
- 앱 이름:
- 패키지명:
- 한 줄 설명:

## 아키텍처
Clean Architecture. domain → data → presentation 단방향 의존.

### 레이어 규칙
- **domain/model**: freezed 불변 모델. 비즈니스 로직 없음.
- **domain/repository**: abstract 인터페이스만.
- **data/repository_impl**: 구현체. Retrofit 클라이언트 직접 사용.
- **data/remote**: Retrofit @RestApi 클라이언트.
- **presentation/<feature>**: 화면 + 위젯 + 기능 전용 provider.
- **core**: 글로벌 설정/공용 컴포넌트. 다른 레이어에 의존 안 함.

## 기술 스택
| 항목 | 패키지 |
|------|--------|
| 상태관리 | flutter_riverpod + riverpod_annotation (codegen) |
| 라우팅 | go_router |
| 네트워크 | dio + retrofit |
| 직렬화 | freezed + json_serializable |

## 패키지 관리
- 추가: `flutter pub add <package>` 만 사용. pubspec.yaml 직접 편집 금지.
- 코드생성: `dart run build_runner build --delete-conflicting-outputs`

## 코드 스타일
- 주석: 한국어
- 식별자: 영문
- Provider codegen: `@riverpod` 어노테이션 방식

## 커밋 컨벤션
<프로젝트 규칙 추가>
```

---

## Step 7 — 초기 빌드 확인

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter run
```

에러 없으면 완료. 이후 기능별로 `presentation/<feature>/` 폴더 추가하며 개발.

---

## 자주 추가하는 패키지 (필요 시)

```bash
# UI
flutter pub add cached_network_image
flutter pub add flutter_svg
flutter pub add shimmer

# 저장소
flutter pub add shared_preferences
flutter pub add hive_flutter
flutter pub add flutter_secure_storage

# 유틸
flutter pub add intl
flutter pub add logger
```
