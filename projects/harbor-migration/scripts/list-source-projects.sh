#!/bin/bash
set -euo pipefail

# .env 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
if [[ -f "${ENV_FILE}" ]]; then
  set -a
  source "${ENV_FILE}"
  set +a
fi

HARBOR_URL="${HARBOR_SOURCE_URL:-https://harbor.innogrid.com}"
OUTPUT_FILE="data/source_projects.txt"

# migrate_images.csv에서 고유 프로젝트 추출 (헤더 먼저 제거 후 정렬)
tail -n +2 data/migrate_images.csv | cut -d',' -f1 | sort -u > "${OUTPUT_FILE}"

echo "추출된 프로젝트 수: $(wc -l < ${OUTPUT_FILE})"
