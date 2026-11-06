{% snapshot dim_station_snapshot %}

{#
  check_cols 는 station_name 하나뿐입니다.
    자치구   → seed 재발행 노이즈 때문에 무조건 제외 (확정 규칙)
    거치대수 → 24시간 안에 플랩하므로 차원이 아니라 fact 측정값
  여기에 컬럼을 추가하면 버전 행이 폭증하고 SCD2 의 의미가 사라집니다.

  invalidate_hard_deletes=False:
  bikeList 에서 사라진 대여소를 즉시 만료시키지 않습니다. 실시간 응답은 일시적으로
  대여소를 누락시키고(파일럿 측정 항목), 하드 삭제로 처리하면 하루치 결측이 폐소로
  기록됩니다. "운영중" 판정은 is_active 정의(최근 144슬롯 중 1회 이상 등장)가 맡습니다.
#}

{{
    config(
        target_schema='snapshots',
        unique_key='station_id',
        strategy='check',
        check_cols=['station_name'],
        invalidate_hard_deletes=False
    )
}}

select * from {{ ref('int_station_current') }}

{% endsnapshot %}
