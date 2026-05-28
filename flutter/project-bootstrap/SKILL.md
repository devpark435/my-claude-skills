---
name: flutter-project-bootstrap
description: Use when starting a new Flutter project from scratch — scaffolds Clean Architecture folder structure, installs standard packages (Riverpod, go_router, Dio, Retrofit, freezed), creates base files (router, Dio provider, constants), and generates CLAUDE.md. Skip CI/CD setup.
---

# Flutter Project Bootstrap

Flutter 프로젝트 초기 세팅. 실행 순서대로 따를 것.

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

### 옵션 A — 글로벌 flutter 사용
```bash
flutter create <project_name> --org <bundle_prefix> --platforms=<platforms>
# 예 (모바일+웹): flutter create my_app --org com.company --platforms=web,ios,android
cd <project_name>
```

### 옵션 B — fvm로 Flutter 버전 고정 (권장)
```bash
mkdir <project_name> && cd <project_name>
fvm use <version> --force          # 예: fvm use 3.41.5 --force
fvm flutter create . --org <bundle_prefix> --platforms=<platforms>
```

이후 모든 명령은 `fvm flutter ...` / `fvm dart ...` 로 실행. `.fvmrc` 가 자동 생성됨.

**`--platforms` 값**: `web,ios,android,macos,linux,windows` 중 필요한 것만 콤마 구분. 생략 시 전부 생성.

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

> fvm 사용 시 `flutter pub add` → `fvm flutter pub add`

### ⚠️ 알려진 버전 충돌 (2026-05 기준)

riverpod 3.x 생태계 전환기. 다음 충돌이 자주 발생:

1. **`riverpod_lint` / `custom_lint` 호환 부재**
   - `flutter_riverpod ^3.x` + `freezed_annotation ^3.x` + `riverpod_lint` 동시 설치 시 충돌.
   - **해결**: lint 두 개를 일단 제외하고 진행. 호환 버전 나오면 추가.
   - 또는 riverpod 2.6.1 생태계로 다운그레이드 (`flutter_riverpod:^2.6.1`, `riverpod_annotation:^2.6.1`).

2. **`json_annotation` 4.12 vs `json_serializable` 호환 부재**
   - 최신 `json_serializable` 6.13.x 는 `json_annotation ^4.11.0` 까지만 지원.
   - **해결**: `flutter pub add json_annotation:^4.11.0` 으로 명시 핀.

3. **버전 충돌 디버그 팁**
   - `flutter pub deps` 로 의존성 트리 확인.
   - 오류 마지막 줄의 "X is incompatible with Y" 가 단서.
   - 한 패키지를 핀하면 연쇄적으로 풀리는 경우 많음.

---

## Step 3 — 폴더 구조 생성

```bash
mkdir -p lib/core/{constant,provider,router,util,component}
mkdir -p lib/domain/{model,repository,usecase}
mkdir -p lib/data/{repository_impl,remote,local}
mkdir -p lib/presentation
mkdir -p test/helpers

# 빈 폴더도 git에 추적되도록 .gitkeep 추가
find lib test -type d -empty -exec touch {}/.gitkeep \;
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
# Codegen
*.g.dart
*.freezed.dart

# Claude 메모리 (로컬 전용)
.claude/
```

> `fvm use` 가 `.gitignore` 를 덮어쓰는 경우 있음. Flutter 표준 gitignore 항목이 누락됐는지 확인 (`.dart_tool/`, `/build/`, `.idea/` 등).

---

## Step 6 — CLAUDE.md 생성

`.claude/CLAUDE.md` 에 생성 (루트 아님). `.gitignore` 에 `.claude/` 가 있어야 원격에 안 올라감.

```bash
mkdir -p .claude
# 아래 템플릿을 .claude/CLAUDE.md 로 저장
```

아래 내용을 프로젝트에 맞게 채울 것:

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

## Step 7 — widget_test.dart 수정

`flutter create` 가 만든 `test/widget_test.dart` 는 기본 `MyApp` 클래스 참조. `main.dart` 를 교체했으니 깨짐. 다음으로 교체:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:<project_name>/main.dart';

void main() {
  testWidgets('App boots', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
  });
}
```

---

## Step 8 — Git 초기화 + 커밋 템플릿 + 리모트

```bash
git init
# .gitmessage 파일을 회사 표준 양식으로 작성 (또는 다른 프로젝트에서 복사)
git config commit.template .gitmessage

# 리모트 등록 (예: GitHub, AWS CodeCommit, GitLab)
git remote add origin <repo_url>

# AWS CodeCommit HTTPS 사용 시
git config credential.helper '!aws codecommit credential-helper $@'
git config credential.UseHttpPath true
```

`.gitmessage` 표준 양식 (회사 컨벤션):

```
# <type>(<scope>): <subject>           # 50자 이내, 한글 OK
#
# [<영역 또는 파일명>]
# - <변경 내용>
#
# types: feat | fix | chore | refactor | docs | test | perf | style
# scope: 프로젝트 도메인 맞춰 정의
#
# 절대 금지 (자동 트레일러/AI 흔적):
# - Co-Authored-By: Claude *
# - 🤖 Generated with [Claude Code]
# - Signed-off-by / Reviewed-by
# - 본문 내 "AI" / "Claude" / "Generated" 표시
```

---

## Step 9 — 초기 빌드 확인

```bash
dart run build_runner build           # fvm: fvm dart run build_runner build
flutter analyze
flutter run
```

> `--delete-conflicting-outputs` 옵션은 build_runner 최신에서 제거됨 (warning만 출력).

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
