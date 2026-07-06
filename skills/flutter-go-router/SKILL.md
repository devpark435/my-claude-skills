---
name: flutter-go-router
description: Use when setting up GoRouter with auth guards, redirect logic, ShellRoute tab navigation, route parameter extraction, saved route restore after login, or wiring refreshListenable to Riverpod state in Flutter projects.
---

# Flutter go_router

## Overview

GoRouter 핵심 패턴: `refreshListenable + redirect` 인증 가드, public/protected 경로 분리, 로그인 후 저장 경로 복원, 쿼리 파라미터 추출.

## GoRouter 기본 세팅

```dart
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerConfigProvider = Provider<GoRouter>((ref) {
  GoRouter.optionURLReflectsImperativeAPIs = true;  // 명령형 push도 URL 반영

  final authNotifier = ref.read(authProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    routes: [
      ...mainRoutes(),
      ...authRoutes(),
    ],
    initialLocation: AppRouter.splash.path,
    observers: [AppRouterObserver()],
    refreshListenable: authNotifier,       // 상태 변경 시 redirect 재실행
    redirect: authNotifier.redirectLogic,  // 인증 가드 로직
  );
});
```

## 인증 가드 — redirect 로직

```dart
class AuthChangeNotifier extends ChangeNotifier {
  // 보호 불필요 경로
  static const _publicPaths = {'/splash', '/permission', '/auth', '/'};
  // 로그인 상태에서 접근 차단할 경로
  static const _authFlowPaths = {'/auth', '/signup', '/phone-login'};

  Future<String?> redirectLogic(BuildContext context, GoRouterState state) async {
    final user = ref.read(userInfoProvider);
    final path = state.uri.path;

    // 로딩 중 → 대기
    if (user is UserResLoading) return null;

    // Splash → 목적지 결정
    if (path == AppRouter.splash.path) {
      await Future.delayed(const Duration(milliseconds: 1500));
      return _resolveDestination();
    }

    final isLoggedIn = user is UserGetRes;

    if (isLoggedIn) {
      // 인증 플로우 경로 → 홈으로
      if (_authFlowPaths.contains(path)) return AppRouter.root.path;

      // 로그인 전 저장했던 경로 복원
      final prefs = await ref.read(sharedPrefsProvider.future);
      final savedRoute = prefs.getString(PrefsKeys.expectedRouteAfterLogin);
      if (savedRoute != null) {
        await prefs.remove(PrefsKeys.expectedRouteAfterLogin);
        return savedRoute;
      }
      return null;
    }

    // 비로그인 + 보호 경로 → 경로 저장 후 /auth 로
    if (!_publicPaths.contains(path)) {
      final prefs = await ref.read(sharedPrefsProvider.future);
      await prefs.setString(
        PrefsKeys.expectedRouteAfterLogin,
        state.uri.toString(),  // 쿼리 파라미터 포함 전체 URI
      );
      return AppRouter.auth.path;
    }

    return null;
  }
}
```

**저장 경로 복원 패턴:** 비로그인 사용자가 보호 경로 접근 → URI 저장 → 로그인 완료 후 자동 복원.

## refreshListenable 연결 — Riverpod → ChangeNotifier

```dart
class AuthChangeNotifier extends ChangeNotifier {
  final Ref ref;

  AuthChangeNotifier({required this.ref}) {
    // userInfoProvider 상태 변경 시 notifyListeners() → GoRouter redirect 재실행
    ref.listen<UserResBase?>(userInfoProvider, (previous, next) {
      final wasLoading = previous is UserResLoading;
      final wasLoggedIn = previous is UserGetRes;
      final isLoggedIn = next is UserGetRes;
      if (wasLoading || wasLoggedIn != isLoggedIn) {
        notifyListeners();
      }
    });
  }
}

final authProvider = ChangeNotifierProvider<AuthChangeNotifier>(
  (ref) => AuthChangeNotifier(ref: ref),
);
```

## 쿼리 파라미터 추출

```dart
// 라우트 정의
GoRoute(
  path: AppRouter.signup.path,
  name: AppRouter.signup.name,
  builder: (context, state) {
    final isSocial = state.uri.queryParameters['social'] == 'true';
    return SignupScreen(isSocial: isSocial);
  },
),

// 탭 인덱스 전달
GoRoute(
  path: '/',
  pageBuilder: (context, state) {
    final tabIndex = int.tryParse(
      state.uri.queryParameters['initialTabIndex'] ?? '',
    ) ?? 0;
    return NoTransitionPage(
      key: state.pageKey,
      child: MainTabScreen(initialTabIndex: tabIndex),
    );
  },
  routes: [
    // 탭 단축 리다이렉트
    GoRoute(
      path: 'home',
      name: AppRouter.home.name,
      redirect: (_, __) => '/?initialTabIndex=0',
    ),
  ],
),
```

## 탭바 — NoTransitionPage

```dart
// 탭 전환 시 전환 애니메이션 없애기
pageBuilder: (context, state) => NoTransitionPage(
  key: state.pageKey,
  child: MainTabScreen(initialTabIndex: tabIndex),
),
```

## 라우터 상수 관리

```dart
enum AppRouter {
  root(path: '/'),
  splash(path: '/splash'),
  auth(path: '/auth'),
  signup(path: '/signup'),
  home(path: '/home'),
  ;

  const AppRouter({required this.path});
  final String path;

  String get name => toString().split('.').last;
}
```

## 흔한 실수

| 실수 | 결과 | 수정 |
|------|------|------|
| `refreshListenable` 없이 redirect 만 설정 | 로그인해도 화면 안 바뀜 | `authNotifier` 연결 필수 |
| `redirectLogic` 에서 null 대신 현재 경로 반환 | 무한 리다이렉트 | 이동 불필요 시 `null` 반환 |
| `state.uri.toString()` 대신 `state.uri.path` 저장 | 쿼리 파라미터 유실 | `toString()` 으로 전체 URI 저장 |
| 탭 전환에 일반 `pageBuilder` | 탭마다 전환 애니메이션 | `NoTransitionPage` 사용 |
| `GoRouter.optionURLReflectsImperativeAPIs` 미설정 | `context.push` 가 URL 에 미반영 | 최상단에서 `true` 설정 |
