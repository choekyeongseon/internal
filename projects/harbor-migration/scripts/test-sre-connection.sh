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

echo "[$(date '+%Y-%m-%d %H:%M:%S')] SRE Harbor 연결 테스트 시작"

# API ping 테스트
curl -sf -k -u "${HARBOR_USER}:${HARBOR_TARGET_PASSWORD}" \
     "${HARBOR_URL}/api/v2.0/ping" || {
  echo "ERROR: SRE Harbor 연결 실패"
  exit 1
}

echo "[$(date '+%Y-%m-%d %H:%M:%S')] SRE Harbor 연결 성공"
