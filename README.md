# Claude Skills

Claude Code 커스텀 스킬 모음. 카테고리별로 구성됨.

## 카테고리

| 카테고리 | 설명 | 스킬 수 |
|----------|------|---------|
| [flutter/](flutter/) | Flutter 앱 개발 전용 스킬 | 8 |
| [react/](react/) | React 앱 개발 전용 스킬 | 1 |
| [marketing/](marketing/) | 마케팅 도구 연동 스킬 | 1 |

## 전체 스킬 목록

### Flutter

| 스킬 이름 | 트리거 상황 |
|-----------|-------------|
| `flutter-project-bootstrap` | 새 Flutter 프로젝트 초기 세팅 시작할 때 |
| `flutter-riverpod-patterns` | Riverpod 프로바이더, AsyncValue, codegen 작성할 때 |
| `flutter-go-router` | GoRouter 설정, auth guard, ShellRoute 탭 네비게이션 |
| `flutter-retrofit-dio` | Dio 인터셉터, Retrofit 클라이언트, 401 토큰 갱신 |
| `flutter-golden-tdd` | Golden 테스트 작성, matchesGoldenFile 인프라 세팅 |
| `flutter-ios-simulator-qa` | iOS 시뮬레이터 QA 자동화 스크립트 생성/실행 |
| `flutter-owasp-security` | 보안 감사, OWASP Mobile Top 10 취약점 검사 |
| `flutter-figma-mcp` | Figma URL → Flutter 위젯 변환 |

### React

| 스킬 이름 | 트리거 상황 |
|-----------|-------------|
| `react-project-bootstrap` | 새 React 프로젝트 초기 세팅 시작할 때 (Vite + TS + Zustand + TanStack) |

### Marketing

| 스킬 이름 | 트리거 상황 |
|-----------|-------------|
| `meta-ads-setup` | Meta Ads MCP 초기 연동 세팅 |

## 스킬 사용법

스킬은 Claude Code에서 자동으로 감지됨. 트리거 상황에 맞는 작업을 요청하면 Claude가 해당 스킬을 자동 호출.

수동 호출:
```
/flutter-project-bootstrap
/meta-ads-setup
```
