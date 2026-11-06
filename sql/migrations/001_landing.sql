-- 랜딩 테이블 DDL — dbt가 소유하지 않습니다 (decisions.md D4).
-- dbt 는 models/staging/_sources.yml 에서 source 로 "선언만" 합니다.
-- 이유: dbt 가 소유하면 `dbt run` 이 랜딩을 재생성할 수 있고,
--       그러면 원문 보존과 멱등 적재의 PK 가 dbt 실행에 걸립니다.
--
-- 적용: psql "$DATABASE_URL" -f sql/migrations/001_landing.sql   (멱등 — 재실행 안전)

create schema if not exists raw;

-- 공공자전거 실시간 대여정보 -------------------------------------------------
-- 그레인 (station_id, slot_ts). 이 PK 가 멱등 적재의 근거입니다:
-- 같은 구간을 두 번 적재하면 두 번째 INSERT 의 영향 행수가 0 이어야 합니다.
create table if not exists raw.bike_status (
    station_id        text        not null,
    slot_ts           timestamptz not null,  -- 10분 floor, UTC (decisions.md D1)
    station_name      text,
    parking_bike_cnt  integer,
    rack_tot_cnt      integer,
    shared            integer,               -- 소스가 계산해 준 거치율. 원문 보존용이고
                                             -- 창고 계층으로 넘기지 않습니다 (erd.md §3)
    fetched_at        timestamptz not null,  -- 속성. 그레인이 아닙니다
    collect_batch_id  uuid        not null,
    constraint bike_status_pkey primary key (station_id, slot_ts)
) partition by range (slot_ts);

-- 파티션은 로더가 적재 직전에 만듭니다 (CREATE TABLE IF NOT EXISTS … PARTITION OF).
-- 과거 구간 백필에서도 같은 경로를 씁니다.

-- 기상청 ASOS 시간자료 --------------------------------------------------------
-- QC 플래그는 버리지 않고 보존합니다 (decisions.md B).
-- 주의: ts 의 플래그만 소스 철자가 tsQcflg 입니다 (a 없음). 컬럼명을 소스에 맞춥니다.
create table if not exists raw.weather_hourly (
    stn_id      text        not null,
    obs_ts      timestamptz not null,  -- ASOS tm(KST) → UTC 변환
    ta          numeric, ta_qcflag text,
    rn          numeric, rn_qcflag text,
    ws          numeric, ws_qcflag text,
    wd          numeric, wd_qcflag text,
    hm          numeric, hm_qcflag text,
    pa          numeric, pa_qcflag text,
    ps          numeric, ps_qcflag text,
    ss          numeric, ss_qcflag text,
    ts          numeric, ts_qcflg  text,
    fetched_at  timestamptz not null,
    constraint weather_hourly_pkey primary key (stn_id, obs_ts)
);
