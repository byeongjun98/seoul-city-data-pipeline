-- decisions.md D6 의 조건 테스트.
--
-- D6 은 '미매칭' 을 accepted_values 에 **포함**시키기로 했습니다. 그 결정이
-- 성립하는 조건은 "양을 보는 상한 테스트가 따로 있다" 하나입니다 —
-- accepted_values 가 '미매칭' 을 허용하는 순간, 미매칭률이 0% 에서 100% 로
-- 치솟아도 걸러낼 장치가 없어지기 때문입니다.
--
-- ⚠️ 이 테스트가 생긴 경위를 적어둡니다. D6 은 작성 당시 "상한 테스트가 이미
--    있습니다" 라고 썼지만 **사실이 아니었습니다.** 실제로는
--    docs/model/schema-tests.planned.yml 에 `expression: "1 = 1"` 자리표시자로
--    들어가 있었고, 그 파일은 model-paths 밖이라 dbt 가 읽지도 않습니다.
--    즉 상시 통과하는 테스트조차 실행되지 않는 상태였습니다 (PAR-17 리뷰 지적 ①).
--    그래서 안전장치를 dbt 가 실제로 실행하는 위치로 옮겼습니다.
--
-- 임계는 파일럿 **이전에** 고정합니다. 측정값을 보고 나서 임계를 정하면
-- 그건 임계가 아니라 현재 상태의 기록입니다.
--   · 현재 값 10% — 사전 등록한 잠정 상한입니다. 근거는 아래 비대칭입니다:
--     매칭 실패는 주소 파싱 실패이고, 서울시 주소 체계에서 자치구 토큰이
--     10% 넘게 깨진다면 그건 데이터 이상이 아니라 파서 버그입니다.
--   · 파일럿 후 "실측률 + 2%p (최소 1%p 여유)" 로 **좁히십시오.** 넓히는 방향은
--     파서 버그를 정상으로 승인하는 것이므로, 넓혀야 한다면 그 이유를
--     decisions.md 에 쓰고 나서 넓히십시오.
--
-- 행이 반환되면 실패입니다. seed 가 비어 있는 동안은 0행이라 통과합니다 —
-- 이 테스트는 데이터가 들어오는 순간부터 의미를 갖습니다.

{% set unmatched_rate_cap = 0.10 %}

with counted as (
    select
        count(*)                                           as total_cnt,
        count(*) filter (where gu_name = '미매칭')          as unmatched_cnt
    from {{ ref('stg_station_master') }}
)

select
    total_cnt,
    unmatched_cnt,
    unmatched_cnt::numeric / total_cnt as unmatched_rate
from counted
where total_cnt > 0
  and unmatched_cnt::numeric / total_cnt > {{ unmatched_rate_cap }}
