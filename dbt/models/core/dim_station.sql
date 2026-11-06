-- 그레인 (station_sk) · 자연키+유효기간 (station_id, valid_from)
--
-- fact 는 station_sk 를 참조하지 않습니다 (decisions.md D4).
-- SCD2 에서 station_sk 는 버전마다 바뀌는 키라서, 명칭이 한 번 변경되면
-- PARTITION BY station_sk 로 잡은 시계열이 버전 경계에서 끊깁니다.
-- fact 는 불변 자연키 station_id 를 들고, station_sk 는 차원 행 식별자로만 둡니다.

select
    dbt_scd_id      as station_sk,
    station_id,
    station_name,
    station_no,
    addr1,
    addr2,
    gu_name,
    lat,
    lon,
    dbt_valid_from  as valid_from,
    dbt_valid_to    as valid_to,
    (dbt_valid_to is null) as is_current

from {{ ref('dim_station_snapshot') }}
