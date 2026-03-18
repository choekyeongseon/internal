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

# 옵션 파싱
SAMPLE_COUNT=0
while [[ $# -gt 0 ]]; do
  case $1 in
    --sample) SAMPLE_COUNT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

SOURCE_REGISTRY="${HARBOR_SOURCE_URL:-harbor.innogrid.com}"
SOURCE_REGISTRY="${SOURCE_REGISTRY#https://}"
SOURCE_REGISTRY="${SOURCE_REGISTRY#http://}"
TARGET_REGISTRY="${HARBOR_TARGET_URL:-harbor.sre.local}"
TARGET_REGISTRY="${TARGET_REGISTRY#https://}"
TARGET_REGISTRY="${TARGET_REGISTRY#http://}"
TARGET_USER="${HARBOR_TARGET_USER:-sre-admin}"
MIGRATE_LIST="data/migrate_images.csv"
LOG_FILE="logs/verify-$(date +%Y%m%d).log"

# 디렉토리 생성
mkdir -p logs

verify_digest() {
  local project="$1"
  local repo="$2"
  local tag="$3"
  local expected_digest="$4"

  # 대상 Harbor API로 실제 digest 조회 (skopeo 대신 curl 사용)
  # repo 이름에 슬래시 포함 시 URL 인코딩 필요 (예: library/nginx → library%2Fnginx)
  local encoded_repo=$(echo "${repo}" | sed 's|/|%2F|g')
  local actual_digest=$(curl -sf -k \
    -u "${TARGET_USER}:${HARBOR_TARGET_PASSWORD}" \
    "https://${TARGET_REGISTRY}/api/v2.0/projects/${project}/repositories/${encoded_repo}/artifacts/${tag}" | \
    jq -r '.digest' 2>/dev/null || echo "")

  if [[ "${actual_digest}" == "${expected_digest}" ]]; then
    echo "PASS: ${project}/${repo}:${tag}" | tee -a "${LOG_FILE}"
    return 0
  else
    echo "FAIL: ${project}/${repo}:${tag} (expected: ${expected_digest}, actual: ${actual_digest})" | tee -a "${LOG_FILE}"
    return 1
  fi
}

# 샘플 추출
if [[ ${SAMPLE_COUNT} -gt 0 ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 샘플 검증 시작 (${SAMPLE_COUNT}개)" | tee -a "${LOG_FILE}"
  VERIFY_LIST=$(tail -n +2 "${MIGRATE_LIST}" | shuf -n "${SAMPLE_COUNT}")
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 전체 검증 시작" | tee -a "${LOG_FILE}"
  VERIFY_LIST=$(tail -n +2 "${MIGRATE_LIST}")
fi

# 메인 루프
total=$(echo "${VERIFY_LIST}" | wc -l)
count=0
passed=0
failed=0

while IFS=',' read -r project repo tag digest size; do
  ((count++)) || true
  echo "[${count}/${total}] 검증 중: ${project}/${repo}:${tag}" | tee -a "${LOG_FILE}"

  if verify_digest "${project}" "${repo}" "${tag}" "${digest}"; then
    ((passed++)) || true
  else
    ((failed++)) || true
  fi
done <<< "${VERIFY_LIST}"

# 리포트 생성
generate_report() {
  echo ""
  echo "========== 검증 결과 리포트 =========="
  echo "검증 일시: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "전체: ${total}건"
  echo "성공: ${passed}건"
  echo "실패: ${failed}건"
  if [[ ${total} -gt 0 ]]; then
    echo "성공률: $(( passed * 100 / total ))%"
  fi
  echo "======================================"
}

generate_report | tee -a "${LOG_FILE}"
