-- 그레인 (station_id)
-- seed 에서 오는 속성(주소·자치구·좌표)은 SCD2 추적 대상이 아닙니다 — seed 를
-- 재발행하면 과거 행까지 덮어씁니다. 의도된 동작입니다 (erd.md §5).

{% set gu_names = var('seoul_gu_names') %}

with src as (

    select * from {{ ref('seed_station_master') }}

),

parsed as (

    select
        station_id,
        nullif(trim(addr1), '')                        as addr1,
        nullif(trim(addr2), '')                        as addr2,
        split_part(trim(addr1), ' ', 2)                as gu_token,

        -- 결측 좌표가 NULL 이 아니라 0.0 으로 들어옵니다 (ST-1001 서서울호수공원).
        -- not_null 은 통과합니다 — 값이 있기 때문입니다. 그 좌표는 기니만 해상이고
        -- 자치구 중심을 내면 바다로 끌려갑니다 (decisions.md C).
        nullif(lat, 0)::numeric                        as lat,
        nullif(lon, 0)::numeric                        as lon

    from src

)

select
    station_id,
    addr1,
    addr2,
    case
        when gu_token in ({{ "'" ~ gu_names | join("', '") ~ "'" }}) then gu_token
        else '미매칭'
    end as gu_name,
    lat,
    lon
from parsed
