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
DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    *) shift ;;
  esac
done

# 설정
SOURCE_REGISTRY="${HARBOR_SOURCE_URL:-harbor.innogrid.com}"
SOURCE_USER="${HARBOR_SOURCE_USER:-sre-user}"
BACKUP_DIR="${BACKUP_PATH:-/opt/harbor-backup}"  # TODO: 경로 확정 필요
BACKUP_LIST="data/backup_images.csv"
LOG_FILE="logs/backup-$(date +%Y%m%d).log"
DONE_LOG="logs/backup_done.log"

# --dry-run 모드: 대상 목록만 출력
if [[ "${DRY_RUN}" == "true" ]]; then
  echo "[DRY-RUN] 실제 백업을 수행하지 않습니다."
  tail -n +2 "${BACKUP_LIST}" | while IFS=',' read -r project repo tag digest size; do
    echo "  ${project}/${repo}:${tag} (${size})"
  done
  exit 0
fi

# 디렉토리 생성
mkdir -p "${BACKUP_DIR}" logs
touch "${DONE_LOG}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 백업 시작" | tee -a "${LOG_FILE}"
echo "대상: $(tail -n +2 ${BACKUP_LIST} | wc -l) 이미지" | tee -a "${LOG_FILE}"

# 이미지 백업 함수 (pull → tar 저장 → docker rmi)
backup_image() {
  local project="$1"
  local repo="$2"
  local tag="$3"
  local digest="$4"
  local start_time=$(date +%s)

  local image="${SOURCE_REGISTRY}/${project}/${repo}:${tag}"
  local tar_path="${BACKUP_DIR}/${project}/${repo}"
  local tar_file="${tar_path}/${tag}.tar"

  mkdir -p "${tar_path}"

  # 1. docker pull
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] PULL: ${image}" | tee -a "${LOG_FILE}"
  if ! docker pull "${image}" >> "${LOG_FILE}" 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FAIL: pull 실패 - ${image}" | tee -a "${LOG_FILE}"
    return 1
  fi

  # 2. docker save (tar 저장)
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] SAVE: ${tar_file}" | tee -a "${LOG_FILE}"
  if ! docker save -o "${tar_file}" "${image}" >> "${LOG_FILE}" 2>&1; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FAIL: save 실패 - ${image}" | tee -a "${LOG_FILE}"
    docker rmi "${image}" 2>/dev/null || true
    return 1
  fi

  # 3. docker rmi (로컬 이미지 즉시 삭제)
  docker rmi "${image}" >> "${LOG_FILE}" 2>&1 || true

  local end_time=$(date +%s)
  local elapsed=$((end_time - start_time))
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: ${image} (${elapsed}s)" | tee -a "${LOG_FILE}"
}

# 메인 루프 — 프로세스 치환으로 subshell 문제 해결
total=$(tail -n +2 "${BACKUP_LIST}" | wc -l)
count=0
success=0
failed=0

while IFS=',' read -r project repo tag digest size; do
  ((count++))
  image_key="${project}/${repo}:${tag}"  # local 제거 (루프 내부는 함수 밖)

  # resume: 이미 완료된 이미지 skip
  if grep -qF "${digest}" "${DONE_LOG}" 2>/dev/null; then
    echo "[${count}/${total}] SKIP: ${image_key} (이미 완료)" | tee -a "${LOG_FILE}"
    continue
  fi

  echo "[${count}/${total}] 처리 중: ${image_key}" | tee -a "${LOG_FILE}"

  # 실패해도 abort 하지 않고 다음 이미지 계속 진행
  if backup_image "${project}" "${repo}" "${tag}" "${digest}"; then
    echo "${digest}" >> "${DONE_LOG}"
    ((success++))
  else
    ((failed++))
  fi
done < <(tail -n +2 "${BACKUP_LIST}")  # 프로세스 치환

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 백업 완료: 성공 ${success}, 실패 ${failed}, 전체 ${count}" | tee -a "${LOG_FILE}"
