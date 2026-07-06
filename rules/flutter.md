# Flutter 상시 룰

모든 Flutter 프로젝트 공통. 프로젝트 CLAUDE.md의 고유 정보(레이어 구조·포트·표본 파일)가 항상 우선.

## 명령어 — FVM 필수

`flutter`/`dart` 명령 전부 `fvm` prefix. 버전 드리프트 방지.

```bash
fvm flutter pub get / analyze / test / run
fvm dart run build_runner build --delete-conflicting-outputs   # 코드젠
fvm flutter pub add <package>                                   # 의존성 추가는 이것만
```

## 판단표

| 상황 | 하라 |
|---|---|
| 상태를 UI가 반응해야 함 | `ref.watch` |
| 콜백/이벤트 핸들러 안에서 읽기 | `ref.read` |
| 새 provider | `@riverpod` 어노테이션 + 코드젠 (아래 코드쌍) |
| 토큰/민감정보 저장 | `flutter_secure_storage`만. `shared_preferences` 금지 |
| 의존성 추가 | `fvm flutter pub add` — pubspec.yaml 직접 편집 금지 |
| 모델/API 코드 수정 후 | build_runner 재실행 |
| API 호출 | 프로젝트의 공용 Dio 인스턴스(인터셉터 포함) 경유 — 새 Dio 생성 금지 |

## 코드쌍

Provider — 레거시 팩토리 금지, 코드젠만:
```dart
// ❌ 금지
final userProvider = StateNotifierProvider<UserNotifier, User>((ref) => UserNotifier());

// ✅ @riverpod 코드젠
@riverpod
class UserNotifier extends _$UserNotifier {
  @override User build() => const User();
  void setName(String v) => state = state.copyWith(name: v);
}
```

네트워킹 — 인터셉터 우회 금지:
```dart
// ❌ 금지: 수동 헤더/새 Dio
final dio = Dio();
dio.options.headers['Authorization'] = 'Bearer $token';

// ✅ 프로젝트 공용 dio provider 경유 (인증 인터셉터가 자동 처리)
final api = ref.read(myFeatureApiProvider); // 내부적으로 공용 dio 사용
```

## 금지 (위반 = 잘못된 코드)

- ❌ `*.g.dart` / `*.freezed.dart` 직접 수정 — build_runner 재생성으로만
- ❌ `.env`·시크릿 커밋
- ❌ FVM 우회 (`flutter` 단독 실행)
- ❌ `skip: true`로 테스트 실패 회피
- ❌ 위젯에서 직접 HTTP 호출 — repository/provider 레이어 경유

## 완료 전 자가검증

```bash
fvm flutter analyze        # 0 errors 확인
fvm flutter test           # 테스트 있으면 전부 green
```
코드젠 파일 만졌으면 build_runner 재실행 후 analyze.

## 탈출구

이 표에 없는 케이스 → 같은 프로젝트에서 **가장 유사한 기존 피처 파일을 찾아 그 구조를 미러**. 프로젝트 CLAUDE.md에 표본 파일 목록 있으면 그것부터.
