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

HARBOR_URL="${HARBOR_TARGET_URL:-https://harbor.sre.local}"
HARBOR_USER="${HARBOR_TARGET_USER:-sre-admin}"
PROJECT_LIST="data/source_projects.txt"
LOG_FILE="logs/create-projects-$(date +%Y%m%d).log"

while read -r project; do
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 프로젝트 생성: ${project}" | tee -a "${LOG_FILE}"

  curl -sf -k -X POST \
       -u "${HARBOR_USER}:${HARBOR_TARGET_PASSWORD}" \
       -H "Content-Type: application/json" \
       -d "{\"project_name\": \"${project}\", \"public\": false}" \
       "${HARBOR_URL}/api/v2.0/projects" || {
    echo "WARNING: ${project} 생성 실패 (이미 존재할 수 있음)" | tee -a "${LOG_FILE}"
  }
done < "${PROJECT_LIST}"
