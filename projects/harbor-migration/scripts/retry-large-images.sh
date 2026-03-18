#!/bin/bash
set -a
source "$(dirname "$0")/../.env"
set +a

export PATH="/c/Program Files/Docker/Docker/resources/bin:$PATH"

# Docker 타임아웃 증가 설정
export DOCKER_CLIENT_TIMEOUT=600
export COMPOSE_HTTP_TIMEOUT=600

SOURCE_REGISTRY="${HARBOR_SOURCE_URL#https://}"
SOURCE_REGISTRY="${SOURCE_REGISTRY#http://}"
TARGET_REGISTRY="${HARBOR_TARGET_URL#https://}"
TARGET_REGISTRY="${TARGET_REGISTRY#http://}"

LOG_FILE="$(dirname "$0")/../logs/retry-large-$(date +%Y%m%d_%H%M%S).log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"; }

# Push 실패 이미지 목록
FAILED_IMAGES=(
"ai-platform/kwater-backend:v1-gpu"
"ai-platform/drift-backend:latest"
"ai-platform/opensearch-dashboards:3.5.0"
"ai-platform/automl-ray:2.52.1"
"devops-util/unitycatalog-server:v0.3.1"
"devops-util/jenkins-controller:2.528.2-jdk21"
"devops-util/jenkins-controller:2.516.3-jdk21"
"devops-util/jenkins-inbound-agent:3355.v388858a_47b_33-3-jdk21"
"devops-util/jenkins-inbound-agent:3345.v03dee9b_f88fc-1-jdk21"
"devops-util/jenkins-home:2.499-jdk21"
"gitlab/gitlab-ce:15.11.3"
"ray-torch/ray-torch:latest"
)

log "=== 대형 이미지 재시도 시작 (타임아웃 600초) ==="
log "대상: ${#FAILED_IMAGES[@]}개"

# Docker 로그인
echo "${HARBOR_SOURCE_PASSWORD}" | docker login "${SOURCE_REGISTRY}" -u "${HARBOR_SOURCE_USER}" --password-stdin 2>/dev/null
echo "${HARBOR_TARGET_PASSWORD}" | docker login "${TARGET_REGISTRY}" -u "${HARBOR_TARGET_USER}" --password-stdin 2>/dev/null

success=0
failed=0

for image in "${FAILED_IMAGES[@]}"; do
  src="${SOURCE_REGISTRY}/${image}"
  dst="${TARGET_REGISTRY}/${image}"
  
  log "처리 중: ${image}"
  
  # Pull
  log "  PULL: ${src}"
  if ! docker pull "${src}" >> "${LOG_FILE}" 2>&1; then
    log "  FAIL: pull 실패"
    ((failed++))
    continue
  fi
  
  # Tag
  docker tag "${src}" "${dst}"
  
  # Push (타임아웃 증가)
  log "  PUSH: ${dst}"
  if ! timeout 600 docker push "${dst}" >> "${LOG_FILE}" 2>&1; then
    log "  FAIL: push 실패 (타임아웃 또는 오류)"
    ((failed++))
  else
    log "  SUCCESS: ${dst}"
    ((success++))
  fi
  
  # 정리
  docker rmi "${src}" "${dst}" >> "${LOG_FILE}" 2>&1 || true
done

log "=== 완료: 성공 ${success}, 실패 ${failed} ==="
