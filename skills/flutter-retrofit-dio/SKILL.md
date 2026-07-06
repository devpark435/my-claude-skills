---
name: flutter-retrofit-dio
description: Use when configuring Dio with interceptors, defining Retrofit clients, handling 401/token refresh, setting up auth header injection, mocking Dio for tests, or wrapping Retrofit clients in repositories in Flutter projects.
---

# Flutter Retrofit + Dio

## Overview

Dio + Retrofit 조합에서 반복되는 패턴: 토큰 주입 마커, 4xx 정상 응답 처리, 인터셉터 구조, Repository 래핑, 테스트 mock.

## Dio 설정

```dart
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
      // 4xx = 앱 레이어에서 resultCode 로 처리. 5xx+ 만 DioException.
      validateStatus: (status) => status != null && status < 500,
    ),
  );
  dio.interceptors.add(CustomInterceptor(dio: dio, ref: ref));
  return dio;
});
```

**핵심:** `validateStatus: (status) => status < 500` — 4xx 를 정상 응답으로 받아 `BaseResponse.resultCode` 로 처리. 서버가 200 으로 에러 내려보내는 패턴에 대응.

## CustomInterceptor — 토큰 주입 + 401 처리

```dart
class CustomInterceptor extends Interceptor {
  final Dio dio;
  final Ref ref;

  CustomInterceptor({required this.dio, required this.ref});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // 마커 헤더 감지 → 실제 토큰으로 교체
    if (options.headers['authorization'] == 'true') {
      final token = await ref.read(secureStorageProvider)
          .read(key: EnvConfig.accessTokenKey);
      options.headers.remove('authorization');
      if (token != null && token.isNotEmpty) {
        options.headers['authorization'] = 'Bearer $token';
      }
    }
    return super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    // 401 → 토큰 삭제 + 로그아웃
    if (response.statusCode == HttpStatus.unauthorized) {
      await _clearTokensAndLogout();
    }
    return super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // 5xx, 네트워크, 타임아웃만 여기 도달 (4xx 는 validateStatus 로 필터)
    return handler.reject(err);
  }

  Future<void> _clearTokensAndLogout() async {
    await ref.read(secureStorageProvider).delete(key: EnvConfig.accessTokenKey);
    await ref.read(secureStorageProvider).delete(key: EnvConfig.userIdKey);
  }
}
```

## Retrofit 클라이언트 — 마커 헤더 패턴

```dart
@RestApi()
abstract class AuthClient {
  factory AuthClient(Dio dio, {String baseUrl}) = _AuthClient;

  // 토큰 불필요
  @POST('/sms/send')
  Future<BaseResponse<AuthSmsSendRes>> smsSend({
    @Body() required AuthSmsSendReq body,
  });

  // 마커 헤더 → 인터셉터가 실제 Bearer 토큰으로 교체
  @POST('/refresh')
  @Headers({'authorization': 'true'})
  Future<BaseResponse<AuthLoginRes>> refresh();

  @GET('/me')
  @Headers({'authorization': 'true'})
  Future<BaseResponse<AuthMeRes>> getMe();
}
```

**패턴:** `@Headers({'authorization': 'true'})` 은 마커. 인터셉터가 `'true'` 감지 → 실제 토큰으로 교체. Retrofit 코드에서 토큰 로직 분리.

## Repository 래핑

```dart
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final client = AuthClient(dio, baseUrl: '${EnvConfig.apiBaseUrl}/api/v1/auth');
  return AuthRepositoryImpl(client);
});

class AuthRepositoryImpl implements AuthRepository {
  final AuthClient _client;
  AuthRepositoryImpl(this._client);

  @override
  Future<BaseResponse<AuthSignupRes>> signup({required AuthSignupReq body}) {
    return _client.signup(body: body);
  }
}
```

Repository 는 단순 위임. 비즈니스 로직은 Service/Provider 에서.

## 테스트 Mock

```dart
// test/helpers/dio_mock.dart
({Dio dio, DioAdapter adapter}) makeDioWithMock({BaseOptions? options}) {
  final dio = Dio(options);
  final adapter = DioAdapter(dio: dio);
  return (dio: dio, adapter: adapter);
}

// 사용
test('API 호출', () async {
  final (:dio, :adapter) = makeDioWithMock();
  adapter.onGet('/ping', (s) => s.reply(200, {'data': 'pong'}));

  final client = SomeClient(dio, baseUrl: 'http://test');
  final res = await client.ping();
  expect(res.data, 'pong');
});
```

Dio 인스턴스 실제 사용 → 인터셉터/직렬화 경로 실코드 탐. 응답만 가짜.

## 흔한 실수

| 실수 | 결과 | 수정 |
|------|------|------|
| `validateStatus` 미설정 | 4xx 전부 DioException 발생 | `status < 500` 설정 |
| 마커 헤더 없이 토큰 필요 엔드포인트 | 401 응답 | `@Headers({'authorization': 'true'})` 추가 |
| Repository 에서 직접 Dio 생성 | 인터셉터 미적용 | `dioProvider` 주입 |
| `onError` 에서 4xx 처리 | `validateStatus` 로 4xx 안 들어옴 | `onResponse` 에서 처리 |
