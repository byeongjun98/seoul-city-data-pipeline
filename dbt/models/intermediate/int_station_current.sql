-- 그레인 (station_id) — 대여소별 "현재" 1행.
--
-- 이 모델이 존재하는 이유: 차원 속성이 두 곳에서 옵니다 (decisions.md D3).
--   명칭 · 거치대수  ← bikeList (10분)
--   주소 · 자치구 · 좌표 ← seed (수동 재발행)
-- dbt snapshot 은 소스 테이블 하나만 보므로, 둘을 합친 뷰를 snapshot 대상으로 둡니다.
-- snapshot 실행 주기(1일)가 이 뷰의 해상도이고, 그것이 "명칭이 언제 바뀌었나"의
-- 답을 "그날 중"으로 고정합니다.

with latest as (

    select
        station_id,
        station_name,
        station_no,
        row_number() over (
            partition by station_id
            order by slot_ts desc
        ) as rn
    from {{ ref('stg_bike_status') }}

)

select
    l.station_id,
    l.station_name,
    l.station_no,
    m.addr1,
    m.addr2,

    -- 조인 방향은 bikeList 기준 LEFT JOIN seed 로 확정돼 있습니다.
    -- 미매칭은 마스터 쪽 잉여(폐지 대여소)가 아니라 seed 에 없는 신설 대여소로
    -- 나타나므로 여기서도 '미매칭' 버킷으로 떨어집니다.
    coalesce(m.gu_name, '미매칭') as gu_name,

    m.lat,
    m.lon

from latest l
left join {{ ref('stg_station_master') }} m
    on l.station_id = m.station_id
where l.rn = 1
