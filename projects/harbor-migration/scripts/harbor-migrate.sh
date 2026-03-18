#!/bin/bash
set -euo pipefail

# Windows Docker Desktop PATH 추가
export PATH="/c/Program Files/Docker/Docker/resources/bin:$PATH"

# .env 로드
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
if [[ -f "${ENV_FILE}" ]]; then
  set -a
  source "${ENV_FILE}"
  set +a
fi

# 옵션 파싱
DRY_RUN=false
TARGET_PROJECT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    --project) TARGET_PROJECT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# 설정
SOURCE_REGISTRY="${HARBOR_SOURCE_URL:-harbor.innogrid.com}"
SOURCE_REGISTRY="${SOURCE_REGISTRY#https://}"
SOURCE_REGISTRY="${SOURCE_REGISTRY#http://}"
SOURCE_USER="${HARBOR_SOURCE_USER:-sre-user}"
TARGET_REGISTRY="${HARBOR_TARGET_URL:-harbor.sre.local}"
TARGET_REGISTRY="${TARGET_REGISTRY#https://}"
TARGET_REGISTRY="${TARGET_REGISTRY#http://}"
TARGET_USER="${HARBOR_TARGET_USER:-sre-admin}"
MIGRATE_LIST="data/migrate_images.csv"
LOG_FILE="logs/migrate-$(date +%Y%m%d).log"
DONE_LOG="logs/migrate_done.log"

# secloudit-helm 제외 (별도 처리)
EXCLUDE_PROJECT="secloudit-helm"

# --dry-run 모드: 대상 목록만 출력
if [[ "${DRY_RUN}" == "true" ]]; then
  echo "[DRY-RUN] 실제 마이그레이션을 수행하지 않습니다."
  tail -n +2 "${MIGRATE_LIST}" | grep -v "^${EXCLUDE_PROJECT}," | \
    while IFS=',' read -r project repo tag digest size; do
      [[ -n "${TARGET_PROJECT}" && "${project}" != "${TARGET_PROJECT}" ]] && continue
      echo "  ${project}/${repo}:${tag} (${size})"
    done
  exit 0
fi

# 디렉토리 생성
mkdir -p logs
touch "${DONE_LOG}"

# Docker 로그인
echo "소스 Harbor 로그인..."
echo "${HARBOR_SOURCE_PASSWORD}" | docker login "${SOURCE_REGISTRY}" -u "${SOURCE_USER}" --password-stdin

echo "대상 Harbor 로그인..."
echo "${HARBOR_TARGET_PASSWORD}" | docker login "${TARGET_REGISTRY}" -u "${TARGET_USER}" --password-stdin

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 마이그레이션 시작" | tee -a "${LOG_FILE}"

# 이미지 전송 함수 (pull → tag → push → docker rmi → digest 검증)
migrate_image() {
  local project="$1"
  local repo="$2"
  local tag="$3"
  local expected_digest="$4"
  local start_time=$(date +%s)

  local src_image="${SOURCE_REGISTRY}/${project}/${repo}:${tag}"
  local dst_image="${TARGET_REGISTRY}/${project}/${repo}:${tag}"

  # 1. docker pull (소스에서)
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] PULL: ${src_image}" | tee -a "${LOG_FILE}"
  if ! docker pull "${src_image}" >> "${LOG_FILE}" 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FAIL: pull 실패 - ${src_image}" | tee -a "${LOG_FILE}"
    return 1
  fi

  # 2. docker tag (대상 레지스트리용)
  docker tag "${src_image}" "${dst_image}"

  # 3. docker push (대상으로)
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] PUSH: ${dst_image}" | tee -a "${LOG_FILE}"
  if ! docker push "${dst_image}" >> "${LOG_FILE}" 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FAIL: push 실패 - ${dst_image}" | tee -a "${LOG_FILE}"
    docker rmi "${src_image}" "${dst_image}" 2>/dev/null || true
    return 1
  fi

  # 4. docker rmi (로컬 이미지 즉시 삭제)
  docker rmi "${src_image}" "${dst_image}" >> "${LOG_FILE}" 2>&1 || true

  # 5. digest 검증 (대상 Harbor에서)
  # repo 이름에 슬래시 포함 시 URL 인코딩 필요 (예: library/nginx → library%2Fnginx)
  local encoded_repo=$(echo "${repo}" | sed 's|/|%2F|g')
  local actual_digest=$(curl -sf -k -u "${TARGET_USER}:${HARBOR_TARGET_PASSWORD}" \
    "https://${TARGET_REGISTRY}/api/v2.0/projects/${project}/repositories/${encoded_repo}/artifacts/${tag}" | \
    jq -r '.digest' 2>/dev/null || echo "")

  if [[ "${actual_digest}" != "${expected_digest}" && -n "${expected_digest}" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: digest 불일치 - ${dst_image}" | tee -a "${LOG_FILE}"
    echo "  expected: ${expected_digest}, actual: ${actual_digest}" | tee -a "${LOG_FILE}"
  fi

  local end_time=$(date +%s)
  local elapsed=$((end_time - start_time))
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: ${dst_image} (${elapsed}s)" | tee -a "${LOG_FILE}"
}

# 메인 루프 (secloudit-helm 제외) — 프로세스 치환으로 subshell 문제 해결
if [[ -n "${TARGET_PROJECT}" ]]; then
  total=$(tail -n +2 "${MIGRATE_LIST}" | grep "^${TARGET_PROJECT}," | wc -l)
else
  total=$(tail -n +2 "${MIGRATE_LIST}" | grep -v "^${EXCLUDE_PROJECT}," | wc -l)
fi
echo "대상 이미지: ${total}개" | tee -a "${LOG_FILE}"
count=0
success=0
failed=0

while IFS=',' read -r project repo tag digest size; do
  image_key="${project}/${repo}:${tag}"  # local 제거 (루프 내부는 함수 밖)

  # secloudit-helm 제외
  if [[ "${project}" == "${EXCLUDE_PROJECT}" ]]; then
    echo "[SKIP] ${image_key} - secloudit-helm 별도 처리" | tee -a "${LOG_FILE}"
    continue
  fi

  # --project 옵션: 특정 프로젝트만 처리
  if [[ -n "${TARGET_PROJECT}" && "${project}" != "${TARGET_PROJECT}" ]]; then
    continue
  fi

  ((count++)) || true

  # resume: 이미 완료된 이미지 skip
  if grep -qF "${digest}" "${DONE_LOG}" 2>/dev/null; then
    echo "[${count}/${total}] SKIP: ${image_key} (이미 완료)" | tee -a "${LOG_FILE}"
    continue
  fi

  echo "[${count}/${total}] 처리 중: ${image_key}" | tee -a "${LOG_FILE}"

  # 실패해도 abort 하지 않고 다음 이미지 계속 진행
  if migrate_image "${project}" "${repo}" "${tag}" "${digest}"; then
    echo "${digest}" >> "${DONE_LOG}"
    ((success++)) || true
  else
    ((failed++)) || true
  fi
done < <(tail -n +2 "${MIGRATE_LIST}")  # 프로세스 치환

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 마이그레이션 완료: 성공 ${success}, 실패 ${failed}, 전체 ${count}" | tee -a "${LOG_FILE}"
