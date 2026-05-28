---
name: react-project-bootstrap
description: Use when starting a new React project from scratch — scaffolds vertical codebase folder structure, installs standard packages (Zustand, TanStack Router, TanStack Query, Tailwind CSS), creates base files (router, stores, providers, design-system), and generates CLAUDE.md.
---

# React Project Bootstrap

표준 React 프로젝트 초기 세팅. Vite + TypeScript. 실행 순서대로 따를 것.

## 표준 스택

| 항목 | 선택 |
|------|------|
| 빌드 | Vite |
| 언어 | TypeScript (strict) |
| 상태관리 | Zustand |
| 라우팅 | TanStack Router |
| 데이터 페칭 | TanStack Query |
| 스타일링 | Tailwind CSS v4 |
| 린트 | ESLint + Prettier |

---

## Step 1 — Vite 프로젝트 생성

```bash
npm create vite@latest <project_name> -- --template react-ts
cd <project_name>
```

---

## Step 2 — 패키지 설치

```bash
# 런타임
npm install \
  zustand \
  @tanstack/react-router \
  @tanstack/react-query \
  tailwindcss @tailwindcss/vite

# 개발 전용
npm install -D \
  @tanstack/react-router-devtools \
  @tanstack/react-query-devtools \
  @tanstack/router-plugin \
  @types/node \
  eslint \
  prettier \
  eslint-config-prettier \
  eslint-plugin-react-hooks
```

---

## Step 3 — Tailwind CSS v4 설정

### `vite.config.ts`

```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { tanstackRouter } from '@tanstack/router-plugin/vite'
import path from 'path'

export default defineConfig({
  plugins: [
    tanstackRouter({ target: 'react', quoteStyle: 'single' }),
    react(),
    tailwindcss(),
  ],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
})
```

### `src/index.css`

```css
@import "tailwindcss";
```

---

## Step 4 — 폴더 구조 생성

```bash
mkdir -p src/{routes,shared/{stores,utils,hooks,types},design-system/{Button,Input,Modal,theme}}
```

**최종 구조 — 수직적 코드베이스:**

```
src/
  routes/                     # TanStack Router 파일 기반 라우팅
    __root.tsx                # 루트 레이아웃
    index.tsx                 # / 페이지
    dashboard/
      index.tsx
      -components/            # 라우트 전용 컴포넌트 (- prefix = private)
      -hooks/
    auth/
      login.tsx
      signup.tsx
      -components/
      -store.ts               # auth 전용 Zustand store

  shared/                     # 여러 기능에서 사용되는 공유 코드
    stores/                   # 전역 Zustand stores
      useAuthStore.ts
      useThemeStore.ts
    utils/
    hooks/
    types/

  design-system/              # 도메인 무관 공유 UI 컴포넌트
    Button/
      Button.tsx
      index.ts
    Input/
      Input.tsx
      index.ts
    Modal/
      Modal.tsx
      index.ts
    theme/
      colors.ts
      typography.ts

  main.tsx
  index.css
  routeTree.gen.ts            # TanStack Router 자동 생성
```

### 수직 구조 원칙

- **함께 변경되는 코드는 함께 둔다**
- 라우트/페이지 기준으로 수직 분할
- 라우트 전용 코드 → 해당 라우트 폴더 내 `-` prefix 폴더
- 여러 라우트에서 사용 → `shared/`로 승격
- 도메인 무관 UI → `design-system/`
- `index.ts`로 공개 인터페이스 명시, 내부 구현 숨김

---

## Step 5 — 베이스 파일 생성

### `src/main.tsx`

```tsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import { RouterProvider, createRouter } from '@tanstack/react-router'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { routeTree } from './routeTree.gen'
import './index.css'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60,
      retry: 1,
    },
  },
})

const router = createRouter({
  routeTree,
  context: { queryClient },
  defaultPreloadStaleTime: 0,
})

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router
  }
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
    </QueryClientProvider>
  </React.StrictMode>,
)
```

### `src/routes/__root.tsx`

```tsx
import { createRootRouteWithContext, Outlet } from '@tanstack/react-router'
import { TanStackRouterDevtools } from '@tanstack/react-router-devtools'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'
import type { QueryClient } from '@tanstack/react-query'

interface RouterContext {
  queryClient: QueryClient
}

export const Route = createRootRouteWithContext<RouterContext>()({
  component: RootLayout,
})

function RootLayout() {
  return (
    <>
      <Outlet />
      {import.meta.env.DEV && (
        <>
          <TanStackRouterDevtools position="bottom-right" />
          <ReactQueryDevtools initialIsOpen={false} />
        </>
      )}
    </>
  )
}
```

### `src/routes/index.tsx`

```tsx
import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/')({
  component: HomePage,
})

function HomePage() {
  return (
    <div className="flex min-h-screen items-center justify-center">
      <h1 className="text-4xl font-bold">Home</h1>
    </div>
  )
}
```

### `src/shared/stores/useAuthStore.ts` (예시)

```typescript
import { create } from 'zustand'

interface AuthState {
  token: string | null
  isAuthenticated: boolean
  setToken: (token: string | null) => void
  logout: () => void
}

export const useAuthStore = create<AuthState>()((set) => ({
  token: null,
  isAuthenticated: false,
  setToken: (token) => set({ token, isAuthenticated: !!token }),
  logout: () => set({ token: null, isAuthenticated: false }),
}))
```

### `src/design-system/Button/Button.tsx` (예시)

```tsx
import { type ButtonHTMLAttributes } from 'react'

type ButtonVariant = 'primary' | 'secondary' | 'ghost'
type ButtonSize = 'sm' | 'md' | 'lg'

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant
  size?: ButtonSize
}

const variantStyles: Record<ButtonVariant, string> = {
  primary: 'bg-blue-600 text-white hover:bg-blue-700',
  secondary: 'bg-gray-200 text-gray-900 hover:bg-gray-300',
  ghost: 'bg-transparent text-gray-700 hover:bg-gray-100',
}

const sizeStyles: Record<ButtonSize, string> = {
  sm: 'px-3 py-1.5 text-sm',
  md: 'px-4 py-2 text-base',
  lg: 'px-6 py-3 text-lg',
}

export function Button({
  variant = 'primary',
  size = 'md',
  className = '',
  ...props
}: ButtonProps) {
  return (
    <button
      className={`rounded-lg font-medium transition-colors ${variantStyles[variant]} ${sizeStyles[size]} ${className}`}
      {...props}
    />
  )
}
```

### `src/design-system/Button/index.ts`

```typescript
export { Button } from './Button'
```

---

## Step 6 — TypeScript 설정

### `tsconfig.json` paths 추가

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}
```

---

## Step 7 — CLAUDE.md 생성

프로젝트 루트에 `CLAUDE.md` 생성:

```markdown
# CLAUDE.md — <프로젝트명>

## 프로젝트 개요
- 앱 이름:
- 한 줄 설명:

## 아키텍처
수직적 코드베이스. 기능/도메인 단위 수직 분할.

### 구조 규칙
- **routes/**: TanStack Router 파일 기반 라우팅. 라우트별 수직 구조.
- **routes/<feature>/-components/**: 해당 라우트 전용 컴포넌트. `-` prefix = private.
- **routes/<feature>/-store.ts**: 해당 라우트 전용 Zustand store.
- **shared/**: 여러 라우트에서 사용하는 공유 코드. stores, hooks, utils, types.
- **design-system/**: 도메인 무관 공유 UI 컴포넌트. Tailwind 기반.

### 수직 구조 원칙
- 함께 변경되는 코드는 함께 둔다
- 라우트 전용 코드는 해당 라우트 폴더 안에
- 2개 이상 라우트에서 사용 시 shared/로 승격
- design-system은 비즈니스 로직 없음

## 기술 스택
| 항목 | 패키지 |
|------|--------|
| 빌드 | Vite |
| 상태관리 | Zustand |
| 라우팅 | TanStack Router |
| 데이터 페칭 | TanStack Query |
| 스타일링 | Tailwind CSS v4 |

## 패키지 관리
- 추가: `npm install <package>` 사용
- 개발 전용: `npm install -D <package>`
- package.json 직접 편집 금지

## 코드 스타일
- 주석: 한국어
- 식별자: 영문
- 컴포넌트: named export (default export 금지)
- 파일명: 컴포넌트 PascalCase, 나머지 camelCase
- import alias: `@/` = `src/`

## Zustand 패턴
- 기능 전용 store → 해당 라우트 폴더 내 `-store.ts`
- 전역 store → `shared/stores/`
- store 이름: `use<Name>Store`
- immer 미들웨어는 필요 시 추가

## TanStack Query 패턴
- queryOptions 함수 → 사용하는 컴포넌트와 같은 수직 구조 내
- queryKey 팩토리 패턴 사용 권장

## 커밋 컨벤션
Conventional Commits (feat, fix, chore, docs, refactor, test)
```

---

## Step 8 — 초기 빌드 확인

```bash
npm run dev
```

브라우저에서 확인. 에러 없으면 완료.

---

## 기능 추가 시 패턴

### 새 라우트(기능) 추가

```bash
mkdir -p src/routes/settings/{-components,-hooks}
```

```
src/routes/settings/
  index.tsx                # 페이지 컴포넌트
  -components/             # 전용 컴포넌트
    SettingsForm.tsx
  -hooks/
    useSettings.ts
  -store.ts                # 전용 Zustand store
  -queries.ts              # 전용 TanStack Query options
```

### 공유 코드 승격

라우트 전용 코드가 2곳 이상에서 필요해지면:

```
# Before: routes/dashboard/-hooks/useFilter.ts
# After:  shared/hooks/useFilter.ts
```

### design-system 컴포넌트 추가

```bash
mkdir -p src/design-system/Card
```

```
design-system/Card/
  Card.tsx
  index.ts                 # export { Card } from './Card'
```

---

## 자주 추가하는 패키지 (필요 시)

```bash
# 폼
npm install react-hook-form zod @hookform/resolvers

# 유틸
npm install date-fns clsx

# Zustand 미들웨어
npm install immer

# 아이콘
npm install lucide-react

# 애니메이션
npm install framer-motion

# 테스트
npm install -D vitest @testing-library/react @testing-library/jest-dom jsdom
```
