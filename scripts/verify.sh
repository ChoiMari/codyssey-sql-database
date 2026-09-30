#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUERY_FILE="$PROJECT_DIR/queries/queries.sql"
SCHEMA_FILE="$PROJECT_DIR/schema/schema.sql"
COMPOSE=(docker compose --project-directory "$PROJECT_DIR" -f "$PROJECT_DIR/compose.yaml")

failures=0

pass() {
  printf 'PASS  %s\n' "$1"
}

fail() {
  printf 'FAIL  %s\n' "$1" >&2
  failures=$((failures + 1))
}

check_minimum() {
  local description="$1"
  local actual="$2"
  local minimum="$3"
  if (( actual >= minimum )); then
    pass "$description ($actual >= $minimum)"
  else
    fail "$description ($actual < $minimum)"
  fi
}

count_pattern() {
  local pattern="$1"
  local file="$2"
  grep -Eic "$pattern" "$file" || true
}

echo "[1/2] SQL 파일 정적 검증"
table_count="$(count_pattern '^CREATE TABLE ' "$SCHEMA_FILE")"
pk_count="$(count_pattern 'PRIMARY KEY' "$SCHEMA_FILE")"
fk_count="$(count_pattern 'FOREIGN KEY' "$SCHEMA_FILE")"
query_count="$(count_pattern '^-- Query [0-9]{2}$' "$QUERY_FILE")"
inner_join_count="$(count_pattern '^[[:space:]]*INNER JOIN ' "$QUERY_FILE")"
left_join_count="$(count_pattern '^[[:space:]]*LEFT JOIN ' "$QUERY_FILE")"
group_by_count="$(count_pattern '^[[:space:]]*GROUP BY ' "$QUERY_FILE")"

check_minimum "테이블 수" "$table_count" 4
check_minimum "PK 정의 수" "$pk_count" 6
check_minimum "FK 정의 수" "$fk_count" 2
check_minimum "번호가 붙은 핵심 쿼리" "$query_count" 15
check_minimum "INNER JOIN 사용" "$inner_join_count" 2
check_minimum "LEFT JOIN 사용" "$left_join_count" 1
check_minimum "GROUP BY 사용" "$group_by_count" 1

for keyword in 'NOT NULL' 'UNIQUE' 'COUNT\(' 'AVG\(' 'SELECT' 'UPDATE' 'DELETE FROM' 'CREATE INDEX' 'EXISTS'; do
  if grep -Eiq "$keyword" "$SCHEMA_FILE" "$QUERY_FILE"; then
    pass "$keyword 존재"
  else
    fail "$keyword 누락"
  fi
done

if (( failures > 0 )); then
  echo "정적 검증에서 ${failures}개 항목이 실패했습니다." >&2
  exit 1
fi

echo
echo "[2/2] 실행 중인 MySQL 데이터 검증"
if ! command -v docker >/dev/null 2>&1; then
  echo "오류: docker 명령을 찾을 수 없어 DB 검증을 실행할 수 없습니다." >&2
  exit 1
fi

if [[ ! -f "$PROJECT_DIR/.env" ]]; then
  echo "오류: .env 파일이 없습니다. 'cp .env.example .env'를 먼저 실행하세요." >&2
  exit 1
fi

verification_output="$(
  "${COMPOSE[@]}" exec -T mysql \
    sh -c 'exec mysql --default-character-set=utf8mb4 --table -uroot -p"$MYSQL_ROOT_PASSWORD"' \
    < "$PROJECT_DIR/verification/verification.sql"
)"
printf '%s\n' "$verification_output"

if grep -Eq '\|[[:space:]]*FAIL[[:space:]]*\|' <<< "$verification_output"; then
  echo "DB 검증 결과에 FAIL이 있습니다." >&2
  exit 1
fi

echo "PASS  모든 DB 검증 항목"
