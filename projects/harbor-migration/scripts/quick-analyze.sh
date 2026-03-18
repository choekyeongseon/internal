#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../.env"

HARBOR_URL="${HARBOR_SOURCE_URL}"
HARBOR_USER="${HARBOR_SOURCE_USER}"
HARBOR_PASS="${HARBOR_SOURCE_PASSWORD}"
OUTPUT_DIR="${SCRIPT_DIR}/../data"
CUTOFF_DATE="${CUTOFF_DATE:-2024-03-17}"

MIGRATE_FILE="${OUTPUT_DIR}/migrate_images.csv"
BACKUP_FILE="${OUTPUT_DIR}/backup_images.csv"

echo "project,repo,tag,digest,size" > "${MIGRATE_FILE}"
echo "project,repo,tag,digest,size" > "${BACKUP_FILE}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 분석 시작..."

# 프로젝트 목록 가져오기
curl -sf -k -u "${HARBOR_USER}:${HARBOR_PASS}" \
  "${HARBOR_URL}/api/v2.0/projects?page_size=100" > /tmp/projects.json

project_count=$(jq 'length' /tmp/projects.json)
echo "프로젝트 수: ${project_count}"

migrate_count=0
backup_count=0

for i in $(seq 0 $((project_count - 1))); do
  project=$(jq -r ".[$i].name" /tmp/projects.json)
  echo -n "[$((i+1))/${project_count}] ${project}..."

  # 리포지토리 목록
  curl -sf -k -u "${HARBOR_USER}:${HARBOR_PASS}" \
    "${HARBOR_URL}/api/v2.0/projects/${project}/repositories?page_size=100" > /tmp/repos.json 2>/dev/null || echo "[]" > /tmp/repos.json

  repo_count=$(jq 'length' /tmp/repos.json)

  for j in $(seq 0 $((repo_count - 1))); do
    full_repo=$(jq -r ".[$j].name" /tmp/repos.json)
    repo="${full_repo#${project}/}"
    encoded_repo=$(echo "${repo}" | sed 's|/|%2F|g')

    # 아티팩트 목록
    curl -sf -k -u "${HARBOR_USER}:${HARBOR_PASS}" \
      "${HARBOR_URL}/api/v2.0/projects/${project}/repositories/${encoded_repo}/artifacts?page_size=100&with_tag=true" > /tmp/artifacts.json 2>/dev/null || echo "[]" > /tmp/artifacts.json

    art_count=$(jq 'length' /tmp/artifacts.json)

    for k in $(seq 0 $((art_count - 1))); do
      digest=$(jq -r ".[$k].digest // empty" /tmp/artifacts.json)
      size_bytes=$(jq -r ".[$k].size // 0" /tmp/artifacts.json)
      push_time=$(jq -r ".[$k].push_time // empty" /tmp/artifacts.json)
      pull_time=$(jq -r ".[$k].pull_time // empty" /tmp/artifacts.json)
      
      # 태그 목록
      tags=$(jq -r ".[$k].tags[]?.name // empty" /tmp/artifacts.json 2>/dev/null)
      [[ -z "${tags}" ]] && continue

      size_mb=$(awk "BEGIN {printf \"%.2f\", ${size_bytes}/1024/1024}")

      is_migrate=false
      if [[ "${pull_time}" != "0001-01-01T00:00:00.000Z" && "${pull_time}" > "${CUTOFF_DATE}" ]]; then
        is_migrate=true
      elif [[ "${pull_time}" == "0001-01-01T00:00:00.000Z" && "${push_time}" > "${CUTOFF_DATE}" ]]; then
        is_migrate=true
      fi

      for tag in ${tags}; do
        if [[ "${is_migrate}" == "true" ]]; then
          echo "${project},${repo},${tag},${digest},${size_mb}MB" >> "${MIGRATE_FILE}"
          ((migrate_count++)) || true
        else
          echo "${project},${repo},${tag},${digest},${size_mb}MB" >> "${BACKUP_FILE}"
          ((backup_count++)) || true
        fi
      done
    done
  done
  echo " done"
done

echo ""
echo "========== 분석 결과 =========="
echo "마이그레이션 대상: ${migrate_count}개 이미지"
echo "백업 대상: ${backup_count}개 이미지"
echo "================================"
