# seoul-city-data-pipeline

서울 공공자전거 실시간 대여정보와 기상청 ASOS 시간자료를 수집해 적재·변환·집계하는
데이터 파이프라인. 데이터 엔지니어 포트폴리오로 만들고 있습니다.

## 범위

```
수집(GitHub Actions cron) → S3 raw(JSON.gz) → Python 정규화
→ PostgreSQL (dbt: staging → core → mart) → Airflow 오케스트레이션
```

의도적으로 **쓰지 않는 것**: Kafka · Spark · Kubernetes · Terraform · 클라우드 DW.
각각 왜 쓰지 않는지는 `docs/adr/` 에 기록할 예정입니다. 데이터 규모가 요구하지 않는
구성요소를 넣으면 "써봤다"는 말은 되지만 선택의 근거를 설명할 수 없게 됩니다.

## 현재 상태

**스캐폴딩 단계.** 아직 동작하는 파이프라인이 아닙니다.

| | 상태 |
|---|---|
| 데이터 모델 · ERD | 설계 중 |
| 수집기 | 미착수 (API 키 발급 대기) |
| S3 랜딩 | 미착수 |
| dbt 모델 | 미착수 |
| Airflow DAG | 미착수 |

## 지금 있는 것

| 경로 | 설명 |
|---|---|
| `scripts/smoke_s3.py` | S3 API 호환성 확인 (PUT/GET/LIST/DELETE). 표준 라이브러리만으로 SigV4 서명 — 받은 사람이 추가 설치 없이 확인할 수 있게 하려고 의존성을 두지 않았습니다 |
| `scripts/measure_memory.sh` | 컨테이너 조합별 상주 메모리 측정. **아직 이전 구성의 compose 프로파일을 참조하므로 그대로는 동작하지 않습니다** |
| `.env.example` | 필요한 키·접속 정보 목록 |

## 이력에 대해

이 레포는 초기 탐색 단계에서 다른 아키텍처(Kafka + Spark 중심)로 시작했다가,
데이터 규모와 투입 시간에 맞지 않는다고 판단해 범위를 위와 같이 줄였습니다.
그 과정에서 이력을 한 번 초기화했습니다.
