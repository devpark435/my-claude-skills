# React Skills

React 앱 개발 전용 스킬 모음. Vite + TypeScript 기반, 수직적 코드베이스 구조.

## 스킬 목록

### react-project-bootstrap
**트리거:** 새 React 프로젝트 시작

수직적 코드베이스 폴더 구조 생성, 표준 패키지 설치 (Zustand, TanStack Router, TanStack Query, Tailwind CSS v4), base 파일(main.tsx, __root.tsx, stores, design-system) 생성, CLAUDE.md 생성까지 자동화.

**표준 스택:**
- 빌드: Vite
- 언어: TypeScript (strict)
- 상태관리: Zustand
- 라우팅: TanStack Router (파일 기반)
- 데이터 페칭: TanStack Query
- 스타일링: Tailwind CSS v4
- 린트: ESLint + Prettier

**수직 구조 원칙:**
- 함께 변경되는 코드는 함께 둔다
- 라우트 전용 코드 → `routes/<feature>/-components/`, `-hooks/`, `-store.ts`
- 2개 이상 라우트에서 사용 시 `shared/`로 승격
- 도메인 무관 UI → `design-system/`
