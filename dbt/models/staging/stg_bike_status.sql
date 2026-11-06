-- 그레인 (station_id, slot_ts)
-- slot_ts 는 10분 floor 한 논리 슬롯이고 그레인입니다. fetched_at 은 속성입니다.
-- shared 는 여기서 떨어뜨립니다 — 저장하면 마트에서 재집계가 불가능해집니다 (erd.md §3).

with src as (

    select * from {{ source('raw', 'bike_status') }}

)

select
    station_id,
    slot_ts,
    nullif(trim(station_name), '')                              as station_name,

    -- 대여소번호가 명칭 접두에 들어 있습니다 ('102. 망원역 1번출구 앞').
    -- 추출 실패는 NULL 로 둡니다 — 성공률은 파일럿 측정 항목입니다 (n=5 가설).
    (substring(station_name from '^([0-9]+)\.'))::int            as station_no,

    parking_bike_cnt,
    rack_tot_cnt,
    fetched_at,
    collect_batch_id

from src
