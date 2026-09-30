#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE=(docker compose --project-directory "$PROJECT_DIR" -f "$PROJECT_DIR/compose.yaml")

if ! command -v docker >/dev/null 2>&1; then
  echo "오류: docker 명령을 찾을 수 없습니다. README의 Docker Desktop/WSL2 준비 절차를 먼저 진행하세요." >&2
  exit 1
fi

if [[ ! -f "$PROJECT_DIR/.env" ]]; then
  echo "오류: .env 파일이 없습니다. 'cp .env.example .env'를 먼저 실행하세요." >&2
  exit 1
fi

run_sql() {
  local sql_file="$1"
  echo "실행: ${sql_file#$PROJECT_DIR/}"
  "${COMPOSE[@]}" exec -T mysql \
    sh -c 'exec mysql --default-character-set=utf8mb4 -uroot -p"$MYSQL_ROOT_PASSWORD"' \
    < "$sql_file"
}

echo "MySQL과 Adminer 컨테이너를 시작합니다."
"${COMPOSE[@]}" up -d

echo "MySQL이 접속 가능한 상태가 될 때까지 기다립니다."
for attempt in {1..30}; do
  if "${COMPOSE[@]}" exec -T mysql \
    sh -c 'mysqladmin ping -h 127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD" --silent' \
    >/dev/null 2>&1; then
    break
  fi

  if [[ "$attempt" -eq 30 ]]; then
    echo "오류: 60초 안에 MySQL 준비가 완료되지 않았습니다." >&2
    "${COMPOSE[@]}" logs mysql >&2
    exit 1
  fi
  sleep 2
done

echo "주의: library_learning의 기존 학습 테이블을 다시 만듭니다."
run_sql "$PROJECT_DIR/schema/schema.sql"
run_sql "$PROJECT_DIR/data/seed.sql"
run_sql "$PROJECT_DIR/queries/queries.sql"

echo "전체 SQL 실행이 완료되었습니다."
echo "Adminer: http://localhost:8080"
echo "다음 단계: ./scripts/verify.sh"

