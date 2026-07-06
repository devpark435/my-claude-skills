# React 상시 룰

모든 React(+TS) 프로젝트 공통. 프로젝트 CLAUDE.md의 고유 정보(폴더 구조·스택 버전·라우터 종류)가 항상 우선.

## 명령어 (프로젝트 공통 패턴)

```bash
npm run dev / typecheck / lint / test / build
```
`.env` 없으면 실패하는 프로젝트 많음 — 에러 시 `cp .env.example .env` 먼저 확인.

## 판단표

| 상황 | 하라 |
|---|---|
| 컴포넌트 export | named export. default export 금지 |
| 타입 import | `import type { X }` — 값 import와 분리 |
| 서버 데이터 + 로컬 수정 상태 | effect에서 setState 금지 → "base(서버) + override(로컬) 파생" (아래 코드쌍) |
| 클래스 문자열 조합 | `cn()` (clsx+tailwind-merge) — 문자열 덧셈 금지 |
| 의존성 추가 | `npm install <pkg>` — package.json 직접 편집 금지 |
| 데이터 보여주는 화면 | 로딩/에러/빈 3종 상태 전부 처리 (기존 페이지의 Skeleton/EmptyState 패턴 모방) |
| console | `console.log` 금지 — warn/error만 |

## 코드쌍

effect setState 금지 (react-hooks/set-state-in-effect):
```tsx
// ❌ 금지: 서버 데이터를 effect로 로컬 state에 복사
const [rows, setRows] = useState<Row[]>([]);
useEffect(() => { setRows(serverData); }, [serverData]);

// ✅ base + override 파생
const [overrides, setOverrides] = useState<Record<string, Partial<Row>>>({});
const rows = useMemo(
  () => serverData.map(r => ({ ...r, ...overrides[r.id] })),
  [serverData, overrides],
);
```

noUncheckedIndexedAccess — 인덱싱은 `T | undefined`:
```tsx
// ❌ 금지
const first = items[0]!;

// ✅ 가드 또는 명명 상수
const first = items[0];
if (!first) return <EmptyState />;
```

## 금지 (위반 = 잘못된 코드)

- ❌ effect/렌더 중 setState 직접 호출
- ❌ `any`로 타입 회피 — strict 유지
- ❌ `.env`·시크릿 커밋
- ❌ 기존 공용 컴포넌트 있는데 새로 만들기 — `components/ui`·`design-system` 먼저 확인

## 완료 전 자가검증

```bash
npm run typecheck   # 0 errors
npm run lint        # 0 errors
npm run test        # 테스트 있으면 green
```

## 탈출구

이 표에 없는 케이스 → 같은 프로젝트의 **가장 유사한 기존 페이지/컴포넌트를 찾아 그 구조를 미러**. 새 도메인/페이지 추가 절차는 프로젝트 `docs/ARCHITECTURE.md` 있으면 그것 우선.
