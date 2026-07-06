---
name: flutter-riverpod-patterns
description: Use when writing Riverpod providers, handling AsyncValue state, setting up NotifierProvider for actions, using @riverpod codegen with family params, AutoDisposeFamilyNotifier with cleanup, or wiring Riverpod to ChangeNotifier for go_router integration.
---

# Flutter Riverpod Patterns

## Overview

Riverpod 핵심 패턴: `NotifierProvider<Notifier, AsyncValue<T>>` 액션 패턴, `@riverpod` codegen + family, `AutoDisposeFamilyNotifier` + cleanup, `ref.listen` → ChangeNotifier 연결.

## 액션 Provider — NotifierProvider + AsyncValue\<void\>

뮤테이션(submit, apply, delete) 에 쓰는 표준 패턴.

```dart
class ReferralApplyNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);  // 초기 상태 = idle

  Future<ReferralVerifyRes?> apply(String code) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(referralRepositoryProvider);
      final res = await repo.apply(body: ReferralVerifyReq(code: code));

      if (res.isSuccess && res.data != null) {
        state = const AsyncData(null);
        return res.data;
      }

      // 서버 에러 메시지 노출
      state = AsyncError(
        res.resultMsg.isEmpty ? '처리에 실패했습니다' : res.resultMsg,
        StackTrace.current,
      );
      return null;
    } catch (err, st) {
      state = AsyncError(err, st);
      return null;
    }
  }
}

final referralApplyProvider =
    NotifierProvider<ReferralApplyNotifier, AsyncValue<void>>(
  ReferralApplyNotifier.new,
);
```

UI 에서: `ref.listen(referralApplyProvider, (_, next) { next.whenOrNull(error: showSnackBar) })`

## @riverpod Codegen — Family 파라미터

```dart
// 파라미터 없는 FutureProvider
@riverpod
Future<List<ChatRoomListItemRes>> sitterChatRoomList(
  SitterChatRoomListRef ref,
  bool? unreadOnly,  // family 파라미터
) async {
  final repository = ref.watch(chatRepositoryProvider);
  final response = await repository.getSitterRooms(unreadOnly: unreadOnly);
  if (response.isSuccess) return response.data?.rooms ?? [];
  throw Exception(response.resultMsg);
}

// 사용: ref.watch(sitterChatRoomListProvider(unreadOnly: true))
```

codegen 장점: `SitterChatRoomListRef` 타입 자동 생성, `family` 보일러플레이트 없음.

## AutoDisposeFamilyNotifier — 리소스 정리

소켓, 스트림, 컨트롤러 등 정리가 필요한 상태.

```dart
class SitterSendMessageNotifier
    extends AutoDisposeFamilyNotifier<AsyncValue<void>, int> {
  @override
  AsyncValue<void> build(int arg) => const AsyncData(null);  // arg = roomId

  Future<void> send({required String content}) async {
    state = const AsyncLoading();
    try {
      final res = await ref.read(chatRepositoryProvider)
          .sendMessage(roomId: arg, body: ChatMessageSendReq(content: content));

      if (res.isSuccess) {
        state = const AsyncData(null);
        ref.invalidate(sitterChatRoomDetailProvider);  // 관련 provider 갱신
      } else {
        state = AsyncError(res.resultMsg, StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final sitterSendMessageProvider = NotifierProvider.autoDispose
    .family<SitterSendMessageNotifier, AsyncValue<void>, int>(
  SitterSendMessageNotifier.new,
);
```

## WebSocket + REST 하이브리드

소켓 + REST 동시 운용 패턴.

```dart
class ActiveChatRoomNotifier
    extends AutoDisposeFamilyNotifier<AsyncValue<ChatRoomState>, int> {
  ChatSocketService? _socketService;
  StreamSubscription? _messageSub;

  @override
  AsyncValue<ChatRoomState> build(int arg) {
    ref.onDispose(() {          // autoDispose 시 정리
      _messageSub?.cancel();
      _socketService?.dispose();
    });
    _init(arg);
    return const AsyncLoading();
  }

  Future<void> _init(int roomId) async {
    try {
      _socketService = ChatSocketService(roomId: roomId);
      await _socketService!.connect();

      _messageSub = _socketService!.onNewMessage.listen(_onNewMessage);

      // REST 로 초기 데이터
      final res = await ref.read(chatRepositoryProvider)
          .getRoomDetail(roomId: roomId);
      state = AsyncData(ChatRoomState.fromRes(res.data!));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void _onNewMessage(ChatMessageRes message) {
    final current = state.valueOrNull;
    if (current == null) return;
    // 중복 제거
    if (current.messages.any((m) => m.id == message.id)) return;
    state = AsyncData(current.copyWith(
      messages: [...current.messages, message],
    ));
  }
}
```

## ref.listen → ChangeNotifier 연결 (go_router 용)

```dart
class AuthChangeNotifier extends ChangeNotifier {
  final Ref ref;

  AuthChangeNotifier({required this.ref}) {
    ref.listen<UserResBase?>(userInfoProvider, (previous, next) {
      final wasLoading = previous is UserResLoading;
      final wasLoggedIn = previous is UserGetRes;
      final isLoggedIn = next is UserGetRes;
      // 로그인 상태 전환 시에만 notifyListeners → GoRouter redirect 재실행
      if (wasLoading || wasLoggedIn != isLoggedIn) notifyListeners();
    });
  }
}
```

## AsyncValue UI 패턴

```dart
// 전체 분기
roomsAsync.when(
  loading: () => const CircularProgressIndicator(),
  error: (e, _) => Text('오류: $e'),
  data: (rooms) => ListView.builder(
    itemCount: rooms.length,
    itemBuilder: (_, i) => RoomTile(rooms[i]),
  ),
);

// 부분 분기
final count = countAsync.maybeWhen(
  data: (v) => v,
  orElse: () => 0,
);

// 로딩 오버레이
ref.watch(submitProvider).isLoading
    ? const LoadingOverlay()
    : const SizedBox.shrink()
```

## 테스트 — ProviderContainer

```dart
ProviderContainer makeContainer({List<Override> overrides = const []}) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}

// 사용
test('apply 성공', () async {
  final repo = MockReferralRepository();
  final container = makeContainer(
    overrides: [referralRepositoryProvider.overrideWithValue(repo)],
  );

  when(() => repo.apply(body: any(named: 'body')))
      .thenAnswer((_) async => BaseResponse(
        resultCode: 200, data: ReferralVerifyRes(valid: true)));

  final res = await container
      .read(referralApplyProvider.notifier)
      .apply('ABCD1234');

  expect(res?.valid, true);
  expect(container.read(referralApplyProvider).hasError, isFalse);
});
```

## 폼 피처 트리플 패턴 (form / form_provider / submit_provider)

폼 기반 피처(가입 단계, 등록 플로우 등)의 표준 3파일 구조. `lib/service/<feature>/` 아래:

```dart
// 1) <feature>_form.dart — 불변 폼 상태
@immutable
class PetForm {
  const PetForm({this.name = '', this.breed = ''});
  final String name;
  final String breed;
  PetForm copyWith({String? name, String? breed}) =>
      PetForm(name: name ?? this.name, breed: breed ?? this.breed);
}

// 2) <feature>_form_provider.dart — setter마다 copyWith
@riverpod
class PetFormNotifier extends _$PetFormNotifier {
  @override PetForm build() => const PetForm();
  void setName(String v) => state = state.copyWith(name: v);
  void setBreed(String v) => state = state.copyWith(breed: v);
}

// 3) <feature>_submit_provider.dart — AsyncValue 반환, API 호출
@riverpod
class PetSubmit extends _$PetSubmit {
  @override AsyncValue<void> build() => const AsyncData(null);
  Future<void> submit() async {
    state = const AsyncLoading();
    final form = ref.read(petFormNotifierProvider);
    state = await AsyncValue.guard(
        () => ref.read(petApiProvider).register(form.toReq()));
  }
}
```

폼 검증은 form_provider의 파생 getter로, 제출 상태 UI는 submit provider의 AsyncValue로 분리 — 한 provider에 섞지 말 것.

## 흔한 실수

| 실수 | 결과 | 수정 |
|------|------|------|
| 액션에서 `ref.watch` 사용 | build() 외부 watch = 에러 | 액션 내부는 `ref.read` |
| `autoDispose` 없이 소켓/스트림 | 화면 닫아도 소켓 유지 | `AutoDisposeFamilyNotifier` + `ref.onDispose` |
| `AsyncError` 에 빈 StackTrace | 디버깅 불가 | `StackTrace.current` 항상 전달 |
| family 파라미터로 복잡 객체 | 동등성 비교 실패 → 캐시 미스 | 단순 타입(int, String) 또는 `==` 구현 |
| 성공 후 관련 provider invalidate 빠뜨림 | 목록이 갱신 안 됨 | `ref.invalidate(listProvider)` |
