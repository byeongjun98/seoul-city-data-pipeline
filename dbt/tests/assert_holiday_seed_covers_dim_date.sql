-- decisions.md D5 의 조건 테스트.
--
-- 손으로 쓴 공휴일 seed 의 유일한 위험은 "범위를 넘었는데 아무도 모르는 것"입니다.
-- is_holiday 는 LEFT JOIN 결과이므로 seed 범위를 넘으면 조용히 false 가 되고,
-- not_null 도 accepted_values 도 통과합니다. 그래서 이 테스트가 필요합니다.
--
-- 행이 반환되면 실패입니다. seed 를 연장하면 통과합니다.

with seed_bound as (
    select max(date_key) as max_seed_date
    from {{ ref('seed_holiday') }}
)

select d.date_key
from {{ ref('dim_date') }} d
cross join seed_bound b
where b.max_seed_date is null       -- seed 가 비어 있음
   or d.date_key > b.max_seed_date  -- dim_date 가 seed 범위를 넘어섬
