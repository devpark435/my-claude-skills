# FastAPI 상시 룰

모든 FastAPI 프로젝트 공통. 프로젝트 CLAUDE.md의 고유 정보(DB 종류·응답 봉투 필드·배포)가 항상 우선.

## 판단표

| 상황 | 하라 |
|---|---|
| 새 도메인 추가 | model → schema → service → endpoint → 라우터 등록, 이 순서. 기존 도메인 1개를 표본으로 미러 |
| 비즈니스 로직 위치 | service 레이어. 엔드포인트 핸들러는 얇게 (아래 코드쌍) |
| 설정/시크릿 읽기 | `.env` 경유 (pydantic-settings/dotenv) — 코드에 하드코딩 금지 |
| API 응답 | 프로젝트의 공용 응답 봉투(BaseResponse 류) 준수 — raw dict 반환 금지 |
| REST 경로 | `/api/v1/...` prefix. WebSocket은 `/ws/...` |
| DB 스키마 변경 | 프로젝트 마이그레이션 절차만 (Alembic 등) — 앱에서 create_all 금지 |
| 시간 처리 | 저장/비교 UTC — 표시 변환은 API 경계에서만 |

## 코드쌍

씬 핸들러 — 로직은 service로:
```python
# ❌ 금지: 핸들러 안에서 쿼리+로직+응답 조립 전부
@router.post("/orders")
async def create_order(req: OrderCreate, db: AsyncSession = Depends(get_db)):
    user = await db.execute(select(User).where(...))  # 로직이 핸들러에
    ...30줄...

# ✅ 핸들러는 위임만
@router.post("/orders")
async def create_order(req: OrderCreate, db: AsyncSession = Depends(get_db)):
    data = await order_service.create(db, req)
    return BaseResponse(result_code=200, data=data)
```

async 일관성:
```python
# ❌ 금지: async 핸들러 안 동기 블로킹 호출
@router.get("/x")
async def get_x():
    r = requests.get(url)          # 이벤트루프 블로킹

# ✅ 비동기 클라이언트
    async with httpx.AsyncClient() as c:
        r = await c.get(url)
```

## 금지 (위반 = 잘못된 코드)

- ❌ `.env`·`.pem`·크리덴셜 커밋
- ❌ 타입힌트 없는 새 함수
- ❌ 핸들러에서 ORM 모델 그대로 반환 — schema(Pydantic) 경유
- ❌ 프로덕션 DB/서버 대상 작업을 확인 없이 실행 (쓰기·마이그레이션·재시작은 의도 확인 먼저)

## 완료 전 자가검증

```bash
pytest                      # 테스트 있으면 green
python -c "import app"      # 최소 import 무결성 (엔트리포인트는 프로젝트 CLAUDE.md 참조)
```

## 탈출구

이 표에 없는 케이스 → 같은 프로젝트의 **가장 유사한 기존 도메인(model/schema/service/endpoint 세트)을 찾아 그 구조를 미러**.
