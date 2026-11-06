#!/usr/bin/env bash
# 프로파일 조합별 상주 메모리를 측정합니다 (W1 검증 기준 3).
#
#   ./scripts/measure_memory.sh
#
# 조합마다: up --wait → SETTLE초 안정화 → docker stats 스냅샷 → down
# 결과는 .measurements/ 에 원시 출력으로 남기고, 표를 stdout 에 출력합니다.
# 측정 결과와 해석은 docs/memory-budget.md 에 기록합니다.
#
# 주의: 실행 중 다른 컨테이너가 떠 있으면 수치가 섞입니다. 먼저 전부 내리세요.

set -euo pipefail

cd "$(dirname "$0")/.."

SETTLE="${SETTLE:-60}"
OUTDIR=.measurements
mkdir -p "$OUTDIR"

# 앞의 3개는 검증 기준이 요구하는 조합입니다.
# 4번째는 "세 프로파일 동시 기동은 불가능하다"는 주장을 검증하기 위한 참고 측정입니다.
# 그 주장을 mem_limit 합산만으로 적어두면 근거가 추정이 됩니다.
COMBOS=(
  "core|--profile core"
  "core+spark|--profile core --profile spark"
  "core+observability|--profile core --profile observability"
  "all|--profile core --profile spark --profile observability"
)

down_all() {
  docker compose --profile core --profile spark --profile observability \
    down --remove-orphans >/dev/null 2>&1 || true
}

echo "== 측정 환경 =="
docker info --format 'Docker {{.ServerVersion}}  VM memory {{.MemTotal}} bytes  CPUs {{.NCPU}}' \
  | tee "$OUTDIR/env.txt"
echo "호스트: $(sysctl -n hw.memsize 2>/dev/null || echo '?') bytes, $(sysctl -n hw.ncpu 2>/dev/null || echo '?') CPUs" \
  | tee -a "$OUTDIR/env.txt"
echo "안정화 대기: ${SETTLE}초"
echo

if [[ -n "$(docker ps -q)" ]]; then
  echo "경고: 이미 실행 중인 컨테이너가 있습니다. 수치가 섞일 수 있습니다." >&2
  docker ps --format '  {{.Names}}' >&2
fi

down_all

for combo in "${COMBOS[@]}"; do
  name="${combo%%|*}"
  flags="${combo#*|}"
  slug="${name//+/_}"

  echo "── $name ──"
  # shellcheck disable=SC2086
  if ! docker compose $flags up -d --wait --wait-timeout 300 > "$OUTDIR/$slug.up.log" 2>&1; then
    echo "  ✗ 기동 실패 — $OUTDIR/$slug.up.log 확인" >&2
    tail -20 "$OUTDIR/$slug.up.log" >&2
    down_all
    exit 1
  fi
  echo "  기동 완료, ${SETTLE}초 안정화 대기"
  sleep "$SETTLE"

  # health 상태를 함께 기록해야 "health OK 상태의 메모리"임을 주장할 수 있습니다.
  docker compose $flags ps --format '{{.Name}}\t{{.State}}\t{{.Status}}' \
    > "$OUTDIR/$slug.ps.txt"
  docker stats --no-stream \
    --format '{{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.CPUPerc}}' \
    > "$OUTDIR/$slug.stats.txt"

  cat "$OUTDIR/$slug.stats.txt"
  python3 - "$OUTDIR/$slug.stats.txt" <<'PY'
import sys, re
UNITS = {"B": 1, "KiB": 1024, "MiB": 1024**2, "GiB": 1024**3,
         "KB": 1000, "MB": 1000**2, "GB": 1000**3}

def to_bytes(s):
    m = re.fullmatch(r"([\d.]+)\s*([A-Za-z]+)", s.strip())
    return float(m.group(1)) * UNITS[m.group(2)]

total = 0.0
for line in open(sys.argv[1]):
    parts = line.rstrip("\n").split("\t")
    if len(parts) < 2:
        continue
    total += to_bytes(parts[1].split("/")[0])
print(f"  합계 {total / 1024**2:.0f} MiB ({total / 1024**3:.2f} GiB)")
PY
  echo

  down_all
done

echo "원시 출력: $OUTDIR/"
echo "docs/memory-budget.md 의 측정 표를 위 수치로 갱신하세요."
