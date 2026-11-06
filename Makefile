.PHONY: venv migrate parse build test docs clean-db
.DEFAULT_GOAL := parse

VENV      := .venv
DBT       := $(VENV)/bin/dbt
DBT_DIR   := dbt
PG_CONT   := cityops-pg-local

export DBT_PROFILES_DIR := $(CURDIR)/$(DBT_DIR)

venv:  ## dbt 설치 (dbt-postgres 최신이 1.11.0 이라 core 도 1.11 대로 고정)
	python3.11 -m venv $(VENV)
	$(VENV)/bin/pip install --upgrade pip
	$(VENV)/bin/pip install "dbt-core~=1.11.0" "dbt-postgres==1.11.0"
	cd $(DBT_DIR) && ../$(DBT) deps

migrate:  ## 랜딩 테이블 DDL 적용 (멱등 — 재실행 안전)
	psql "$(DATABASE_URL)" -v ON_ERROR_STOP=1 -f sql/migrations/001_landing.sql

parse:  ## DB 없이 정적 검증. CI 와 같은 명령입니다
	cd $(DBT_DIR) && ../$(DBT) parse --no-partial-parse --show-all-deprecations

build:  ## seed → run → snapshot → test 전부
	cd $(DBT_DIR) && ../$(DBT) build

test:
	cd $(DBT_DIR) && ../$(DBT) test

docs:  ## lineage 는 여기서 나옵니다. ERD 는 lineage 를 중복하지 않습니다
	cd $(DBT_DIR) && ../$(DBT) docs generate && ../$(DBT) docs serve

clean-db:  ## 검증용 일회성 Postgres 제거
	docker rm -f $(PG_CONT) 2>/dev/null || true
