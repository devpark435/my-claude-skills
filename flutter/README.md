# Flutter Skills

Flutter 앱 개발 전용 스킬 모음. 회사 표준 스택(Riverpod, go_router, Dio, Retrofit, freezed) 기준.

## 스킬 목록

### flutter-project-bootstrap
**트리거:** 새 Flutter 프로젝트 시작

Clean Architecture 폴더 구조 생성, 표준 패키지 설치, base 파일(router, Dio provider, constants) 생성, CLAUDE.md 생성까지 자동화.

---

### flutter-riverpod-patterns
**트리거:** Riverpod 코드 작성 시

- `@riverpod` 코드젠 패턴
- `AsyncValue` 상태 처리
- `NotifierProvider` 액션 설정
- `AutoDisposeFamilyNotifier` cleanup
- go_router 연동용 `ChangeNotifier` wiring

---

### flutter-go-router
**트리거:** 라우팅 설정 시

- auth guard + redirect 로직
- `ShellRoute` 탭 네비게이션
- 로그인 후 저장 경로 복원
- `refreshListenable` → Riverpod 연동

---

### flutter-retrofit-dio
**트리거:** 네트워크 레이어 작성 시

- Dio 인터셉터 설정
- Retrofit 클라이언트 정의
- 401 토큰 갱신 처리
- auth 헤더 자동 주입
- Dio 모킹 테스트

---

### flutter-golden-tdd
**트리거:** 위젯/화면 골든 테스트 작성 시

- `matchesGoldenFile` 인프라 세팅
- □ 박스 폰트 렌더링 문제 해결
- CI용 골든 PNG 안정화
- 다중 enum 상태 테스트

---

### flutter-ios-simulator-qa
**트리거:** iOS 시뮬레이터 QA 자동화 필요 시

- QA 스크립트 생성/수정
- tap/swipe/screenshot 테스트
- 기능별 또는 회귀 테스트 실행

---

### flutter-owasp-security
**트리거:** 보안 감사, 출시 전 보안 점검 시

OWASP Mobile Top 10 (2024) 기준. 자동 스캐너(M1/M2/M5/M9) + Dio/Retrofit/Riverpod/GoRouter 수동 점검.

---

### flutter-figma-mcp
**트리거:** Figma URL 공유 또는 디자인 구현 요청 시

Figma 참조 코드를 프로젝트 컨벤션(AppColor, AppTextStyles, AppRouter, SvgPicture)에 맞게 변환. 코드 제안만 — 파일 직접 수정 안 함.
