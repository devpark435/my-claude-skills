---
name: react-admin-patterns
description: Use when adding domains, list/detail pages, tables, filters, or CRUD flows to a React admin dashboard built on the shared admin skeleton (react_kpharm_admin / react_taxhotel_admin style) — BaseResponse normalization, page hooks, HeaderActionsContext, div-based tables, useFilteredTable.
---

# React 어드민 패턴 (사내 골격 공통)

## Overview

react_kpharm_admin 골격 기반 어드민 공통 방법론. 이 골격 특징: axios+BaseResponse 정규화, 페이지별 훅 분리, div 테이블, HeaderActionsContext. 신규 어드민도 이 골격 미러.

## 데이터 흐름 (한 방향)

```
페이지 훅(useXxxQuery/useXxxMutations) → domainApi.xxx() → apiClient(axios+인터셉터)
  → BaseResponse<T> → 훅에서 unwrap/unwrapList → 컴포넌트
```

- `BaseResponse`가 백엔드 불일치 흡수: 문자열/숫자 result_code, camel/snake, `data.data` 중첩, list 위치. **컴포넌트에서 응답 방어 코드 금지** — 정규화는 BaseResponse 한 곳.
- 토큰: 요청 인터셉터가 authStore에서 Bearer 자동 부착. 401 → logout + `/login`. 수동 헤더 금지.
- Query 설정: staleTime 5분, retry 1, refetchOnWindowFocus off. 전역 onError → `handleApiError`(toast+Sentry).
- Query key: `['도메인', '뷰', id]` 계층 배열. mutation 후 invalidate → 재조회. **낙관적 업데이트 안 씀.**

## 새 도메인 추가 절차 (순서 고정)

1. `src/domains/<domain>/types.ts` — 타입 정의
2. `src/domains/<domain>/api.ts` — `domainApi` 객체 (apiClient 호출 + unwrap)
3. `src/api/endpoints.ts` — 경로 상수 추가
4. `src/pages/<Domain>/hooks/` — `useXxxQuery.ts`, `useXxxMutations.ts`
5. `src/pages/<Domain>/components/` — 페이지 전용 컴포넌트
6. 라우트 등록 (`App.tsx`) — `lazy()` + `Suspense(PageSkeleton)`
7. 사이드바 `MENU` 추가 (`components/layout/Sidebar.tsx`)

레포에 `docs/ARCHITECTURE.md` 있으면 그 절차가 우선.

## 페이지 골격

```tsx
export function PharmaciesPage() {
  // 1) 헤더는 Context로 주입 — 페이지 안에서 <h1> 직접 렌더 금지
  const { setNode, setRightNode } = useHeaderActions();
  useEffect(() => {
    setNode(<PageTitle>약국 관리</PageTitle>);
    setRightNode(<Button onClick={...}>추가</Button>);
    return () => { setNode(null); setRightNode(null); };
  }, []);

  // 2) 데이터는 페이지 훅
  const { data, isLoading, isError } = usePharmaciesQuery();

  // 3) 3종 상태 필수
  if (isLoading) return <TableSkeleton />;
  if (isError) return <ErrorState />;
  if (!data?.length) return <EmptyState />;
  return <PharmacyTable rows={data} />;
}
```

## 테이블 — `<table>` 태그 금지

div+flex 커스텀: 헤더 40px, 행 48px, `min-w-[Npx]` + `overflow-x-auto` 래퍼. 기존 테이블 컴포넌트 하나 열어 구조 복사.
검색+필터+페이지네이션은 `useFilteredTable` 훅 재사용 — 새로 구현 금지.

## 폼 — react-hook-form 안 씀

패키지 설치돼 있어도 미사용 (일관성). `useState` + 제출 시 inline 검증(`showError()`).
zod는 `env.ts` 전용 — 폼/API 스키마 검증에 사용 금지.

## 자가검증

```bash
npm run typecheck && npm run lint && npm run test
```

## 탈출구

애매하면 기존 완성 도메인 하나(예: 약국 관리)를 열어 **전 파일 세트를 미러**. ADR 문서(`docs/adr/`) 있으면 구조 결정 근거 확인.
