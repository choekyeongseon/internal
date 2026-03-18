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

TARGET_URL="${HARBOR_TARGET_URL:-https://harbor.sre.local}"
TARGET_REGISTRY="${TARGET_URL#https://}"
MIGRATE_LIST="data/migrate_images.csv"
LOG_FILE="logs/test-pull-$(date +%Y%m%d).log"

# 디렉토리 생성
mkdir -p logs

test_pull() {
  local project="$1"
  local repo="$2"
  local tag="$3"

  local image="${TARGET_REGISTRY}/${project}/${repo}:${tag}"

  echo "Pull 테스트: ${image}" | tee -a "${LOG_FILE}"
  if docker pull "${image}" >> "${LOG_FILE}" 2>&1; then
    docker rmi "${image}" >> "${LOG_FILE}" 2>&1 || true
    echo "SUCCESS: ${image}" | tee -a "${LOG_FILE}"
    return 0
  else
    echo "ERROR: Pull 실패 - ${image}" | tee -a "${LOG_FILE}"
    return 1
  fi
}

echo "=== Pull 테스트 시작 ===" | tee -a "${LOG_FILE}"

# 샘플 추출
if [[ ${SAMPLE_COUNT} -gt 0 ]]; then
  echo "샘플 ${SAMPLE_COUNT}개 테스트" | tee -a "${LOG_FILE}"
  TEST_LIST=$(tail -n +2 "${MIGRATE_LIST}" | shuf -n "${SAMPLE_COUNT}")
else
  # 기본: 각 프로젝트에서 1개씩 샘플 선택
  echo "프로젝트별 1개씩 테스트" | tee -a "${LOG_FILE}"
  TEST_LIST=$(tail -n +2 "${MIGRATE_LIST}" | sort -t',' -k1,1 -u)
fi

# 메인 루프
total=$(echo "${TEST_LIST}" | wc -l)
count=0
passed=0
failed=0

while IFS=',' read -r project repo tag digest size; do
  ((count++))
  echo "[${count}/${total}] 테스트 중: ${project}/${repo}:${tag}" | tee -a "${LOG_FILE}"

  if test_pull "${project}" "${repo}" "${tag}"; then
    ((passed++))
  else
    ((failed++))
  fi
done <<< "${TEST_LIST}"

echo "" | tee -a "${LOG_FILE}"
echo "=== Pull 테스트 완료 ===" | tee -a "${LOG_FILE}"
echo "전체: ${total}, 성공: ${passed}, 실패: ${failed}" | tee -a "${LOG_FILE}"
