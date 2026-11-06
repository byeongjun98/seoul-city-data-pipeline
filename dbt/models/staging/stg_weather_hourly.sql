-- 그레인 (stn_id, obs_ts)
-- 결측 표현이 null / '' / '-' 3종 혼용이라 측정값마다 정규화합니다.
-- QC 플래그는 버리지 않습니다 — 버리면 "왜 이 행이 격리됐나"를 창고 안에서
-- 설명할 수 없습니다 (decisions.md B).

with src as (

    select * from {{ source('raw', 'weather_hourly') }}

)

-- 측정값 9종과 QC 플래그 9종을 짝으로 유지합니다. 한쪽만 통과시키면
-- "플래그는 있는데 그 플래그가 가리키는 값이 없는" 상태가 되고, 데이터가
-- 없는 동안은 테스트로도 안 잡힙니다 (PAR-17 리뷰 지적 ②).
select
    stn_id,
    obs_ts,

    ta,
    rn,
    ws,
    wd,
    hm,
    pa,
    ps,
    ss,
    ts,

    -- 소스 플래그를 본인 룰보다 먼저 씁니다. 기상청이 "검사에서 걸렸다"고
    -- 표시한 것이 직접 만든 범위 룰보다 정확합니다.
    nullif(trim(ta_qcflag), '') as ta_qcflag,
    nullif(trim(rn_qcflag), '') as rn_qcflag,
    nullif(trim(ws_qcflag), '') as ws_qcflag,
    nullif(trim(wd_qcflag), '') as wd_qcflag,
    nullif(trim(hm_qcflag), '') as hm_qcflag,
    nullif(trim(pa_qcflag), '') as pa_qcflag,
    nullif(trim(ps_qcflag), '') as ps_qcflag,
    nullif(trim(ss_qcflag), '') as ss_qcflag,

    -- 철자 주의: 소스가 tsQcflg 입니다. 명시적으로 적고 생성하지 않습니다.
    -- 짝인 ts(지면온도)가 위 측정값 목록에 있는지 함께 확인하세요.
    nullif(trim(ts_qcflg), '')  as ts_qcflg,

    fetched_at

from src
