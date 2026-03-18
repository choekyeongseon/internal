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

# 설정
HARBOR_URL="${HARBOR_SOURCE_URL:-https://harbor.innogrid.com}"
HARBOR_USER="${HARBOR_SOURCE_USER:-sre-user}"
HARBOR_PASS="${HARBOR_SOURCE_PASSWORD}"
OUTPUT_DIR="${SCRIPT_DIR}/../data"
CUTOFF_DATE="${CUTOFF_DATE:-2024-03-17}"  # 2년 전 기준일

# 출력 파일
MIGRATE_FILE="${OUTPUT_DIR}/migrate_images.csv"
BACKUP_FILE="${OUTPUT_DIR}/backup_images.csv"
TEMP_DIR="${OUTPUT_DIR}/tmp"

mkdir -p "${OUTPUT_DIR}" "${TEMP_DIR}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Harbor 분석 시작"
echo "소스: ${HARBOR_URL}"
echo "기준일: ${CUTOFF_DATE} (이후 사용된 이미지 → 마이그레이션)"

# CSV 헤더
echo "project,repo,tag,digest,size" > "${MIGRATE_FILE}"
echo "project,repo,tag,digest,size" > "${BACKUP_FILE}"

# 프로젝트 목록 조회 (파일로 저장 후 처리 - Windows 호환)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 프로젝트 목록 조회 중..."
curl -sf -k -u "${HARBOR_USER}:${HARBOR_PASS}" \
  "${HARBOR_URL}/api/v2.0/projects?page_size=100" > "${TEMP_DIR}/projects.json" 2>/dev/null || echo "[]" > "${TEMP_DIR}/projects.json"
projects=$(jq -r '.[].name' "${TEMP_DIR}/projects.json")

for project in ${projects}; do
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 프로젝트 처리 중: ${project}"

  # 리포지토리 목록 조회
  curl -sf -k -u "${HARBOR_USER}:${HARBOR_PASS}" \
    "${HARBOR_URL}/api/v2.0/projects/${project}/repositories?page_size=100" > "${TEMP_DIR}/repos.json" 2>/dev/null || echo "[]" > "${TEMP_DIR}/repos.json"

  repo_names=$(jq -r '.[].name' "${TEMP_DIR}/repos.json" 2>/dev/null)
  [[ -z "${repo_names}" ]] && continue

  for full_repo in ${repo_names}; do
    # full_repo는 "project/repo" 형식, repo 부분만 추출
    repo="${full_repo#${project}/}"
    encoded_repo=$(echo "${repo}" | sed 's|/|%2F|g')

    # 아티팩트(태그) 목록 조회
    curl -sf -k -u "${HARBOR_USER}:${HARBOR_PASS}" \
      "${HARBOR_URL}/api/v2.0/projects/${project}/repositories/${encoded_repo}/artifacts?page_size=100&with_tag=true" > "${TEMP_DIR}/artifacts.json" 2>/dev/null || echo "[]" > "${TEMP_DIR}/artifacts.json"

    # 각 아티팩트 처리
    artifact_count=$(jq 'length' "${TEMP_DIR}/artifacts.json" 2>/dev/null || echo "0")

    for ((i=0; i<artifact_count; i++)); do
      jq ".[$i]" "${TEMP_DIR}/artifacts.json" > "${TEMP_DIR}/artifact.json"

      digest=$(jq -r '.digest // empty' "${TEMP_DIR}/artifact.json")
      size_bytes=$(jq -r '.size // 0' "${TEMP_DIR}/artifact.json")
      push_time=$(jq -r '.push_time // empty' "${TEMP_DIR}/artifact.json")
      pull_time=$(jq -r '.pull_time // empty' "${TEMP_DIR}/artifact.json")

      # 태그 목록 가져오기
      tags=$(jq -r '.tags[]?.name // empty' "${TEMP_DIR}/artifact.json" 2>/dev/null || true)

      # 태그가 없으면 skip
      [[ -z "${tags}" ]] && continue

      # 크기를 MB로 변환
      size_mb=$(awk "BEGIN {printf \"%.2f\", ${size_bytes}/1024/1024}")

      # 마이그레이션 여부 판단
      # pull_time이 0001-01-01이면 비어있는 것으로 취급
      is_migrate=false

      if [[ "${pull_time}" != "0001-01-01T00:00:00.000Z" && "${pull_time}" > "${CUTOFF_DATE}" ]]; then
        is_migrate=true
      elif [[ "${pull_time}" == "0001-01-01T00:00:00.000Z" && "${push_time}" > "${CUTOFF_DATE}" ]]; then
        is_migrate=true
      fi

      for tag in ${tags}; do
        if [[ "${is_migrate}" == "true" ]]; then
          echo "${project},${repo},${tag},${digest},${size_mb}MB" >> "${MIGRATE_FILE}"
        else
          echo "${project},${repo},${tag},${digest},${size_mb}MB" >> "${BACKUP_FILE}"
        fi
      done
    done
  done
done

# 임시 파일 정리
rm -rf "${TEMP_DIR}"

# 결과 집계
migrate_count=$(( $(wc -l < "${MIGRATE_FILE}") - 1 ))
backup_count=$(( $(wc -l < "${BACKUP_FILE}") - 1 ))

echo ""
echo "========== 분석 결과 =========="
echo "마이그레이션 대상: ${migrate_count}개 이미지"
echo "백업 대상: ${backup_count}개 이미지"
echo ""
echo "출력 파일:"
echo "  - ${MIGRATE_FILE}"
echo "  - ${BACKUP_FILE}"
echo "================================"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 분석 완료"
