---
name: fastapi-service-patterns
description: Use when adding domains, endpoints, services, DB models, or Alembic migrations to a FastAPI backend — layered structure (endpoints→services→models), BaseResponse envelope, async SQLAlchemy sessions, router registration order, 422 normalization.
---

# FastAPI 서비스 패턴

## Overview

레이어드 FastAPI 백엔드 공통 방법론 (howlpot_fastapi 표본). 핵심: 씬 핸들러, service에 로직, Alembic만으로 스키마 변경, 공용 응답 봉투.

## 구조 (표준 레이아웃)

```
app.py 또는 main.py     # 엔트리: app 생성, 라우터 수동 등록, 예외 핸들러, CORS, lifespan
core/                   # config(pydantic-settings), database(async engine/session), middleware
api/deps.py             # 공유 의존성 (auth, get_db)
api/v1/endpoints/       # 도메인당 모듈 1개. admin은 서브패키지
services/               # 비즈니스 로직
models/                 # SQLAlchemy ORM
schemas/                # Pydantic 요청/응답
alembic/                # 마이그레이션
```

## 새 도메인 추가 (순서 고정)

1. `models/<domain>.py` — ORM 모델
2. `alembic revision --autogenerate -m "..."` → `alembic upgrade head` (앱은 create_all 안 함)
3. `schemas/<domain>.py` — 요청/응답 Pydantic
4. `services/<domain>_service.py` — 로직
5. `api/v1/endpoints/<domain>.py` — 씬 핸들러
6. `app.py`에 `include_router` 등록 — **순서 주의**: 명시 경로(`/reservations/recurring/*`)를 `{id}` 와일드카드 라우터보다 먼저

## 핸들러 표준형

```python
@router.post("/items", response_model=BaseResponse[ItemOut])
async def create_item(
    req: ItemCreate,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    data = await item_service.create(db, user, req)
    return BaseResponse(result_code=200, result_msg="ok", data=data)
```

- 핸들러에 쿼리/분기 로직 금지 — service로.
- 응답은 항상 프로젝트 봉투(`{result_code, result_msg, data}` 류). 422도 전역 핸들러가 같은 모양으로 재작성(클라이언트 에러 경로 단일화).
- ORM 모델 직접 반환 금지 — schema 경유.

## DB 세션/비동기

- 세션은 `Depends(get_db)` 주입만 — 직접 세션 생성 금지.
- async 핸들러에서 동기 블로킹(requests, time.sleep) 금지 → httpx.AsyncClient / asyncio.sleep.
- 시간: 저장/비교 UTC, 표시 변환은 API 경계(core/time 유틸)에서.

## 설정/시크릿

- `core/config.py`의 `settings` 싱글톤 경유. `.env`에서만 읽기.
- FCM/외부 SDK는 크리덴셜 없으면 disabled 모드로 부팅 (부팅 실패 금지 패턴).

## 자가검증

```bash
pytest                          # green
alembic upgrade head            # 마이그레이션 적용 확인 (스키마 변경 시)
```

## 탈출구

애매하면 기존 도메인 1개의 **model→schema→service→endpoint 세트를 통째로 미러**. 배포/서버 접속은 프로젝트 CLAUDE.md 참조 (프로덕션 주의 문구 준수).
