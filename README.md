# seoul-city-data-pipeline

서울 공공자전거 실시간 대여정보와 기상청 ASOS 시간자료를 수집해 적재·변환·집계하는
데이터 파이프라인. 데이터 엔지니어 포트폴리오로 만들고 있습니다.

## 범위

```
수집(GitHub Actions cron) → S3 raw(JSON.gz) → Python 정규화
→ PostgreSQL (dbt: staging → core → mart) → Airflow 오케스트레이션
```

의도적으로 **쓰지 않는 것**: Kafka · Spark · Kubernetes · Terraform · 클라우드 DW.
각각 왜 쓰지 않는지는 `docs/adr/` 에 기록할 예정입니다. 데이터 규모가 요구하지 않는
구성요소를 넣으면 "써봤다"는 말은 되지만 선택의 근거를 설명할 수 없게 됩니다.

## 현재 상태

**스캐폴딩 단계.** 데이터가 아직 한 행도 들어오지 않았습니다.

| | 상태 |
|---|---|
| 데이터 모델 · ERD | ✅ `docs/model/` |
| dbt 프로젝트 · 그레인 테스트 | ✅ `dbt parse` 경고 0 / `dbt build` 45 PASS (아래 단서) |
| 랜딩 DDL | ✅ `sql/migrations/001_landing.sql` (멱등) |
| 공휴일 seed | ⬜ 헤더만 — 채우기 전까지 `dbt build` 는 의도적으로 실패합니다 |
| 수집기 | ⬜ 미착수 (API 키 발급 후) |
| core fact · mart | ⬜ 미착수 (테스트는 선행 작성됨) |
| Airflow DAG | ⬜ 미착수 |

### "45 PASS" 를 그대로 믿지 마십시오

데이터가 한 행도 없으므로 **대부분의 통과는 0행에 대한 공허한 통과입니다.** seed 가 헤더만이고
랜딩에 적재할 로더가 없어서 `stg_*` → `int_*` → `dim_station` 까지 전부 0행으로 흐릅니다.
실제 행을 거치는 테스트는 `dim_date` 의 730행(`date_spine` 생성, seed 무관)뿐입니다.

테스트 **설계** 자체는 합성 행 주입으로 확인했습니다 — 음수 `parking_bike_cnt` 와 좌표 `0.0`
을 넣으면 해당 테스트가 즉시 실패하고, 미매칭 자치구 비율을 17% 로 올리면 상한 테스트가
실패합니다. 다만 숫자가 주는 신뢰도는 데이터가 들어오는 순간부터 달라집니다.

**테스트가 데이터보다 먼저 커밋돼 있습니다.** 그레인 유일성 테스트는
`dbt/models/*/schema.yml` 에 있고, 아직 모델이 없는 계층의 테스트는
`docs/model/schema-tests.planned.yml` 에 미리 써 뒀습니다. 순서가 바뀌면 테스트는
"현재 데이터가 이렇다"는 서술이 되고 틀린 적재를 잡아내지 못합니다.

## 돌려보기

**요구사항**: Docker, 그리고 **`python3.11`** (`make venv` 가 이 이름을 그대로 호출합니다 —
`python3` 가 3.11 이어도 `python3.11` 이 PATH 에 없으면 실패합니다. macOS 는
`brew install python@3.11`).

```bash
make venv          # dbt 1.11 설치 + dbt deps
make parse         # DB 없이 정적 검증 — CI 가 돌리는 것과 같은 명령

# 전체 빌드 (Postgres 필요)
# ⚠️ 호스트 5432 를 쓰지 않습니다. 로컬에 이미 Postgres 가 떠 있으면(Homebrew 서비스 등)
#    컨테이너는 정상 기동하는데 접속만 기존 DB 로 가고, 증상이
#    `role "cityops" does not exist` 로 나타나 포트 충돌처럼 보이지 않습니다.
docker run -d --name cityops-pg-local -p 55432:5432 \
  -e POSTGRES_USER=cityops -e POSTGRES_PASSWORD=cityops -e POSTGRES_DB=cityops \
  postgres:16-alpine
export PGHOST=localhost PGPORT=55432 PGUSER=cityops PGPASSWORD=cityops PGDATABASE=cityops
export DATABASE_URL="postgresql://cityops:cityops@localhost:55432/cityops"
make migrate && make build
```

`make build` 는 현재 **45 PASS / 1 ERROR** 로 끝납니다. 그 1건은
`assert_holiday_seed_covers_dim_date` 이고 **설계된 실패**입니다 — 공휴일 seed 가
비어 있으면 `dim_date.is_holiday` 가 조용히 전부 `false` 가 되므로, 그 상태에서
빌드를 세우는 테스트를 먼저 넣었습니다. seed 를 채우면 통과합니다.

## 지금 있는 것

| 경로 | 설명 |
|---|---|
| `docs/model/erd.md` | Mermaid ERD — 물리 키 · 카디널리티 · SCD2 유효기간 · 그레인 튜플. lineage 는 `dbt docs` 가 만들므로 중복하지 않습니다 |
| `docs/model/decisions.md` | 모델 결정 7건 + 추가 4건. 선택지 · 트레이드오프 · 근거 |
| `dbt/` | dbt 프로젝트. staging 3 · intermediate 1 · snapshot 1 · core 2 |
| `sql/migrations/001_landing.sql` | 랜딩 테이블 DDL. **dbt 가 소유하지 않습니다** — dbt 가 소유하면 `dbt run` 이 랜딩을 재생성할 수 있고 멱등 적재의 PK 가 dbt 실행에 걸립니다 |
| `scripts/smoke_s3.py` | S3 API 호환성 확인 (PUT/GET/LIST/DELETE). 표준 라이브러리만으로 SigV4 서명 — 받은 사람이 추가 설치 없이 확인할 수 있게 하려고 의존성을 두지 않았습니다 |
| `scripts/measure_memory.sh` | 컨테이너 조합별 상주 메모리 측정. **이전 구성의 compose 프로파일을 참조하므로 그대로는 동작하지 않습니다** |
| `.env.example` | 필요한 키·접속 정보 목록 |

## 이력에 대해

이 레포는 초기 탐색 단계에서 다른 아키텍처(Kafka + Spark 중심)로 시작했다가,
데이터 규모와 투입 시간에 맞지 않는다고 판단해 범위를 위와 같이 줄였습니다.
그 과정에서 이력을 한 번 초기화했습니다.
