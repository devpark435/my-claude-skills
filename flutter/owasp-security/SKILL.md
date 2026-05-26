---
name: flutter-owasp-security
description: Use when performing security audits, vulnerability assessments, or pre-release security checks on Flutter apps. Covers OWASP Mobile Top 10 (2024) with automated scanners (M1/M2/M5/M9) and Dio/Retrofit/Riverpod/GoRouter-specific manual checks.
---

# Flutter OWASP Security Checker

스택 특화: Dio + Retrofit + Riverpod + GoRouter

## 스크립트 경로

```bash
SCRIPTS="$HOME/Desktop/claude_skills/flutter-owasp-security/scripts"
```

---

## 전체 자동 스캔

프로젝트 루트에서 실행:

```bash
SCRIPTS="$HOME/Desktop/claude_skills/flutter-owasp-security/scripts"
python3 "$SCRIPTS/scan_hardcoded_secrets.py" .
python3 "$SCRIPTS/check_dependencies.py" .
python3 "$SCRIPTS/check_network_security.py" .
python3 "$SCRIPTS/analyze_storage_security.py" .
```

출력 파일:
- `owasp_m1_secrets_scan.json`
- `owasp_m2_dependencies_scan.json`
- `owasp_m5_network_scan.json`
- `owasp_m9_storage_scan.json`

---

## Workflow

```text
종합 감사?
├─ YES → 전체 자동 스캔 → JSON 결과 검토 → 수동 분석(M3/M4/M6/M7/M8/M10) → 리포트
└─ NO → 아래 계속

특정 카테고리?
├─ M1 → scan_hardcoded_secrets.py
├─ M2 → check_dependencies.py
├─ M5 → check_network_security.py (Dio/Retrofit baseUrl 포함)
├─ M9 → analyze_storage_security.py
└─ M3/M4/M6/M7/M8/M10 → 아래 수동 체크 섹션

배포 전 빠른 체크?
└─ YES → 전체 자동 스캔 → CRITICAL/HIGH만 수정
```

---

## OWASP Mobile Top 10 (2024) 요약

| Risk | 문제 | 자동화 | 핵심 체크 |
|------|------|--------|-----------|
| **M1** | 하드코딩된 자격증명 | ✅ | API 키, 토큰 in 소스/config |
| **M2** | 취약한 의존성 | ✅ | outdated 패키지, any 버전 |
| **M3** | 취약한 인증 | 수동 | 토큰 저장, MFA, 세션 만료 |
| **M4** | 입력 검증 부재 | 수동 | SQL injection, WebView XSS, IDOR |
| **M5** | 불안전한 통신 | ✅ | HTTP 사용, 인증서 피닝 없음 |
| **M6** | 프라이버시 위반 | 수동 | PII in 로그/분석, 과도한 권한 |
| **M7** | 바이너리 보호 없음 | 수동 | `--obfuscate` 빠짐, 루트 감지 없음 |
| **M8** | 보안 설정 오류 | 수동 | debug 플래그 in 프로덕션, 과도한 로깅 |
| **M9** | 불안전한 저장소 | ✅ | SharedPreferences에 민감 데이터 |
| **M10** | 취약한 암호화 | 수동 | MD5/SHA1/ECB, 하드코딩 키 |

---

## 수동 체크: 스택 특화

### M3 — Riverpod 인증 저장

```dart
// ❌ BAD: StateProvider에 토큰 저장
final tokenProvider = StateProvider<String?>((ref) => null);
// → 메모리에만 있음, cold start 시 날아감, 보안 저장소 없음

// ✅ GOOD: flutter_secure_storage + Riverpod
final authRepository = Provider((ref) => AuthRepository(
  storage: const FlutterSecureStorage(),
));

@riverpod
Future<String?> authToken(AuthTokenRef ref) =>
    ref.watch(authRepositoryProvider).getToken();
```

**체크할 것:**
- `StateProvider<String>` or `StateNotifierProvider` 토큰 직접 저장 여부
- `ref.read(tokenProvider.notifier).state = response.token` 패턴
- Riverpod provider가 `flutter_secure_storage` 통해 토큰 읽는지

### M5 — Dio / Retrofit HTTP 사용

```dart
// ❌ BAD: HTTP baseUrl
final dio = Dio(BaseOptions(baseUrl: 'http://api.example.com'));

@RestApi(baseUrl: 'http://api.example.com')
abstract class ApiClient { ... }

// ✅ GOOD: HTTPS
final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
```

**체크할 것:**
- `BaseOptions(baseUrl: 'http://...')` 패턴 → 자동 스캔에 포함됨
- `@RestApi(baseUrl: 'http://...')` 패턴 → 자동 스캔에 포함됨
- 환경별 baseUrl 관리 (`kDebugMode`로 분기 시 프로덕션 값 검증)

### M5 — Dio 인터셉터 보안 로깅

```dart
// ❌ BAD: Authorization 헤더 로깅
dio.interceptors.add(LogInterceptor(
  requestHeader: true,  // Authorization 토큰 노출!
  responseBody: true,   // 민감 응답 데이터 노출!
));

// ✅ GOOD: 프로덕션에서 헤더 로깅 비활성화
dio.interceptors.add(LogInterceptor(
  requestHeader: kDebugMode ? true : false,
  responseBody: kDebugMode ? true : false,
));

// ✅ BETTER: 커스텀 인터셉터에서 민감 헤더 마스킹
@override
void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
  if (kDebugMode) {
    final safeHeaders = Map.of(options.headers)
      ..update('Authorization', (_) => 'Bearer [REDACTED]', ifAbsent: () => '');
    log('Request: ${options.uri} headers: $safeHeaders');
  }
  handler.next(options);
}
```

**체크할 것:**
- `LogInterceptor(requestHeader: true)` → 프로덕션 빌드에서 사용 여부
- `print(options.headers)` or `debugPrint(response.data)` in interceptors
- `kDebugMode` 조건 없는 헤더/바디 로깅

### M4 — GoRouter 민감 파라미터

```dart
// ❌ BAD: 민감 데이터 route path에 포함
GoRoute(path: '/payment/:cardNumber', ...)
GoRoute(path: '/user/:authToken', ...)
// → 로그, analytics, deep link에 노출됨

// ✅ GOOD: POST body 또는 Riverpod state로 전달
GoRoute(
  path: '/payment',
  builder: (context, state) {
    final extra = state.extra as PaymentArgs;
    return PaymentScreen(args: extra);
  },
)
```

**체크할 것:**
- route path에 token, card, password, secret 포함 여부
- `GoRouter` redirect에서 민감 데이터 query param으로 전달 여부
- deep link handler에서 URL 파싱 시 입력 검증 여부

### M8 — 프로덕션 디버그 설정

```dart
// ❌ BAD: 항상 활성화
dio.interceptors.add(LogInterceptor(requestBody: true));
FlutterError.onError = (details) => print(details); // PII 포함 가능

// ✅ GOOD: kDebugMode 조건부
if (kDebugMode) {
  dio.interceptors.add(LogInterceptor(requestBody: true));
}
```

**체크할 것:**
- `LogInterceptor` `kDebugMode` 없이 추가 여부
- `print()` / `debugPrint()` in interceptors without guard
- `FlutterError.onError` → Crashlytics 연결 여부 (PII 필터링)

### M7 — 빌드 설정

```bash
# ❌ BAD: 난독화 없음
flutter build apk --release
flutter build ipa --release

# ✅ GOOD: 난독화 포함
flutter build apk --release --obfuscate --split-debug-info=./debug-info
flutter build ipa --release --obfuscate --split-debug-info=./debug-info
```

**체크할 것:**
- CI/CD 빌드 스크립트에 `--obfuscate` 플래그 여부
- `android/app/build.gradle`에 `minifyEnabled true` 여부
- `flutter_jailbreak_detection` 또는 동등 패키지 사용 여부

---

## 스캔 결과 심각도

| 심각도 | 의미 | 조치 |
|--------|------|------|
| **CRITICAL** | 즉시 악용 가능 | 지금 수정 — 출시 불가 |
| **HIGH** | 심각한 취약점 | 출시 전 수정 |
| **MEDIUM** | 수정 필요 | 다음 스프린트 계획 |
| **LOW** | 모범 사례 개선 | 여유 시 처리 |

### 흔한 False Positive

- **M1**: 테스트/예제 키, `YOUR_API_KEY` 플레이스홀더
- **M2**: dev-only 의존성 (linter, test 도구)
- **M5**: 개발 환경 `localhost`/`127.0.0.1` HTTP
- **M9**: 민감하지 않은 SharedPreferences (테마, 언어 설정)

---

## CI/CD 통합

| 단계 | 액션 |
|------|------|
| Pre-commit | `scan_hardcoded_secrets.py` 실행 |
| Pull Request | 전체 4개 스캐너 실행, 결과 PR 코멘트 |
| Release build | 자동 스캔 + M3/M4/M6/M7/M8/M10 수동 분석 |

---

## 참고 문서

- `references/owasp_mobile_top_10_2024.md` — 카테고리별 Flutter 취약점 패턴, 공격 시나리오, 완화 전략
