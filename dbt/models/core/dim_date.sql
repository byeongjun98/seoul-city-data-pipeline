-- 그레인 (date_key) — KST 달력일.
--
-- 저장은 전부 UTC 이고 KST 는 이 한 지점에만 등장합니다 (decisions.md D1):
--   fact.date_key = (slot_ts AT TIME ZONE 'Asia/Seoul')::date
-- 즉 "하루"가 KST 자정 기준이라는 것은 그 한 줄로 결정됩니다.

with spine as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('" ~ var('dim_date_start') ~ "' as date)",
        end_date="cast('" ~ var('dim_date_end_exclusive') ~ "' as date)"
    ) }}

),

days as (

    select date_day::date as date_key from spine

)

select
    d.date_key,
    extract(year  from d.date_key)::int   as year,
    extract(month from d.date_key)::int   as month,
    extract(isodow from d.date_key)::int  as day_of_week,          -- 1 = 월
    extract(isodow from d.date_key) in (6, 7) as is_weekend,

    -- 출처가 없는 플래그는 테스트를 거짓말하게 만듭니다. seed 가 출처이고,
    -- seed 범위를 넘으면 tests/assert_holiday_seed_covers_dim_date.sql 가
    -- 빌드를 실패시킵니다 (decisions.md D5).
    (h.date_key is not null) as is_holiday,

    case
        when extract(month from d.date_key) in (3, 4, 5)   then '봄'
        when extract(month from d.date_key) in (6, 7, 8)   then '여름'
        when extract(month from d.date_key) in (9, 10, 11) then '가을'
        else '겨울'
    end as season

from days d
left join {{ ref('seed_holiday') }} h
    on d.date_key = h.date_key
