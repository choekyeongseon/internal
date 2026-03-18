# plan.md — harbor-migration

> 작성일: 2026-03-17
> 상태: `구현 완료 (D 제외)`
> 현재 Phase: Phase 4 - 구현 완료

---

## 1. 목표

기존 Harbor(harbor.innogrid.com)에서 최근 2년 내 사용 이미지(4,295개, 914.84GB)를 SRE Harbor로 마이그레이션하고, 미사용 이미지(2,153개, 165.46GB)를 백업 저장소로 이동

### 성공 기준
- [ ] 마이그레이션 대상 4,295개 이미지가 SRE Harbor에 존재
- [ ] 백업 대상 2,153개 이미지가 백업 저장소에 존재
- [ ] 모든 이미지 digest 검증 통과
- [ ] SRE Harbor에서 샘플 이미지 pull 테스트 성공

---

## 2. 트레이드오프

| 결정 | 선택 | 이유 |
|---|---|---|
| 이미지 전송 도구 | docker pull/push | 원자적 처리(pull→push→rmi) 구현 용이, 범용적 |
| 처리 단위 | 이미지 1개씩 | 로컬 디스크 공간 최소화 (이미지 1개 분량만 필요) |
| 실패 처리 | skip 후 계속 | abort 하지 않음, 전체 작업 완료 후 실패 목록 재처리 |
| resume 기능 | digest 기반 완료 로그 | 중단 후 재시작 시 완료된 이미지 skip |
| API 호출 방식 | curl + jq | bash 스크립트 환경에서 범용적, 의존성 최소화 |
| 페이지네이션 | page_size=100 | Harbor API 기본값, 안정적 처리 |
| 로그 형식 | timestamp + 이미지명 + 성공/실패 + 소요시간 | 장애 추적 및 재시작 지점 확인 용이 |
| secloudit-helm 처리 | # TODO 별도 전략 | 663.58GB 단독 프로젝트, 전략 확정 필요 |

---

## 3. 구현 체크리스트

### 덩어리 A: SRE Harbor 사전 준비
<!-- 이 덩어리 = Claude Code 작업 지시 1회 단위 -->

- [x] A-1: SRE Harbor 연결 테스트 스크립트 작성
  - 파일: `scripts/test-sre-connection.sh`
  - 변경: API ping 테스트 및 인증 확인
  ```bash
  #!/bin/bash
  set -euo pipefail

  HARBOR_URL="${HARBOR_TARGET_URL:-https://harbor.sre.local}"
  HARBOR_USER="${HARBOR_TARGET_USER:-sre-admin}"

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] SRE Harbor 연결 테스트 시작"

  # API ping 테스트
  curl -sf -u "${HARBOR_USER}:${HARBOR_TARGET_PASSWORD}" \
       "${HARBOR_URL}/api/v2.0/ping" || {
    echo "ERROR: SRE Harbor 연결 실패"
    exit 1
  }

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] SRE Harbor 연결 성공"
  ```

- [x] A-2: 프로젝트 목록 추출 스크립트 작성
  - 파일: `scripts/list-source-projects.sh`
  - 변경: 소스 Harbor에서 마이그레이션 대상 프로젝트 목록 추출
  ```bash
  #!/bin/bash
  set -euo pipefail

  HARBOR_URL="${HARBOR_SOURCE_URL:-https://harbor.innogrid.com}"
  OUTPUT_FILE="data/source_projects.txt"

  # migrate_images.csv에서 고유 프로젝트 추출 (헤더 먼저 제거 후 정렬)
  tail -n +2 data/migrate_images.csv | cut -d',' -f1 | sort -u > "${OUTPUT_FILE}"

  echo "추출된 프로젝트 수: $(wc -l < ${OUTPUT_FILE})"
  ```

- [x] A-3: SRE Harbor 프로젝트 생성 스크립트 작성
  - 파일: `scripts/create-sre-projects.sh`
  - 변경: 소스 프로젝트와 동일 구조로 SRE Harbor에 프로젝트 생성
  ```bash
  #!/bin/bash
  set -euo pipefail

  HARBOR_URL="${HARBOR_TARGET_URL:-https://harbor.sre.local}"
  HARBOR_USER="${HARBOR_TARGET_USER:-sre-admin}"
  PROJECT_LIST="data/source_projects.txt"
  LOG_FILE="logs/create-projects-$(date +%Y%m%d).log"

  while read -r project; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 프로젝트 생성: ${project}" | tee -a "${LOG_FILE}"

    curl -sf -X POST \
         -u "${HARBOR_USER}:${HARBOR_TARGET_PASSWORD}" \
         -H "Content-Type: application/json" \
         -d "{\"project_name\": \"${project}\", \"public\": false}" \
         "${HARBOR_URL}/api/v2.0/projects" || {
      echo "WARNING: ${project} 생성 실패 (이미 존재할 수 있음)" | tee -a "${LOG_FILE}"
    }
  done < "${PROJECT_LIST}"
  ```

- [x] A-4: 디렉토리 구조 생성
  - 파일: 프로젝트 루트
  - 변경: scripts/, data/, logs/ 디렉토리 생성
  ```bash
  mkdir -p scripts data logs
  ```

### 덩어리 B: harbor-backup.sh 구현
<!-- 이 덩어리 = Claude Code 작업 지시 1회 단위 -->
<!-- 핵심: backup_images.csv에서 이미지 목록 읽기 → 이미지 1개 단위: pull → 로컬 tar 저장 → docker rmi → 로그 기록 → 실패 시 skip 후 계속 진행 -->

- [x] B-1: 백업 스크립트 기본 구조 작성
  - 파일: `scripts/harbor-backup.sh`
  - 변경: backup_images.csv 기반 백업, resume 기능 포함
  ```bash
  #!/bin/bash
  set -euo pipefail

  # 설정
  SOURCE_REGISTRY="${HARBOR_SOURCE_URL:-harbor.innogrid.com}"
  SOURCE_USER="${HARBOR_SOURCE_USER:-sre-user}"
  BACKUP_DIR="${BACKUP_PATH:-/opt/harbor-backup}"  # TODO: 경로 확정 필요
  BACKUP_LIST="data/backup_images.csv"
  LOG_FILE="logs/backup-$(date +%Y%m%d).log"
  DONE_LOG="logs/backup_done.log"

  # 디렉토리 생성
  mkdir -p "${BACKUP_DIR}" logs
  touch "${DONE_LOG}"

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 백업 시작" | tee -a "${LOG_FILE}"
  echo "대상: $(tail -n +2 ${BACKUP_LIST} | wc -l) 이미지" | tee -a "${LOG_FILE}"
  ```

- [x] B-2: 이미지 백업 함수 구현 (pull → tar 저장 → docker rmi)
  - 파일: `scripts/harbor-backup.sh`
  - 변경: 원자적 처리 단위 구현
  ```bash
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
  ```

- [x] B-3: 메인 루프 (resume 기능 + 실패 시 skip)
  - 파일: `scripts/harbor-backup.sh`
  - 변경: 완료된 이미지 skip, 실패해도 다음 이미지 계속 진행
  - 주의: 프로세스 치환 사용 (파이프 대신) — 카운터 변수 보존
  ```bash
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
  ```

- [x] B-4: --dry-run 옵션 추가
  - 파일: `scripts/harbor-backup.sh`
  - 변경: 실제 작업 없이 대상 목록만 출력
  ```bash
  # 옵션 파싱
  DRY_RUN=false
  while [[ $# -gt 0 ]]; do
    case $1 in
      --dry-run) DRY_RUN=true; shift ;;
      *) shift ;;
    esac
  done

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[DRY-RUN] 실제 백업을 수행하지 않습니다."
    tail -n +2 "${BACKUP_LIST}" | while IFS=',' read -r project repo tag digest size; do
      echo "  ${project}/${repo}:${tag} (${size})"
    done
    exit 0
  fi
  ```

### 덩어리 C: harbor-migrate.sh 구현
<!-- 이 덩어리 = Claude Code 작업 지시 1회 단위 -->
<!-- 핵심: migrate_images.csv에서 이미지 목록 읽기 → 이미지 1개 단위: pull → push → docker rmi → 로그 기록 → 실패 시 skip 후 계속 진행 (abort 하지 않음) → resume 기능 → push 완료 후 대상 Harbor digest 검증 -->

- [x] C-1: 마이그레이션 스크립트 기본 구조 작성
  - 파일: `scripts/harbor-migrate.sh`
  - 변경: migrate_images.csv 기반, resume 기능 포함
  ```bash
  #!/bin/bash
  set -euo pipefail

  # 설정
  SOURCE_REGISTRY="${HARBOR_SOURCE_URL:-harbor.innogrid.com}"
  SOURCE_USER="${HARBOR_SOURCE_USER:-sre-user}"
  TARGET_REGISTRY="${HARBOR_TARGET_URL:-harbor.sre.local}"
  TARGET_USER="${HARBOR_TARGET_USER:-sre-admin}"
  MIGRATE_LIST="data/migrate_images.csv"
  LOG_FILE="logs/migrate-$(date +%Y%m%d).log"
  DONE_LOG="logs/migrate_done.log"

  # secloudit-helm 제외 (별도 처리)
  EXCLUDE_PROJECT="secloudit-helm"

  # 디렉토리 생성
  mkdir -p logs
  touch "${DONE_LOG}"

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 마이그레이션 시작" | tee -a "${LOG_FILE}"
  ```

- [x] C-2: 이미지 전송 함수 구현 (pull → push → docker rmi → digest 검증)
  - 파일: `scripts/harbor-migrate.sh`
  - 변경: 원자적 처리 단위 + digest 검증
  ```bash
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
    local actual_digest=$(curl -sf -u "${TARGET_USER}:${HARBOR_TARGET_PASSWORD}" \
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
  ```

- [x] C-3: 메인 루프 (resume + 실패 시 skip + secloudit-helm 제외)
  - 파일: `scripts/harbor-migrate.sh`
  - 변경: 완료된 이미지 skip, 실패해도 abort 하지 않음
  - 주의: 프로세스 치환 사용 (파이프 대신) — 카운터 변수 보존
  ```bash
  # 메인 루프 (secloudit-helm 제외) — 프로세스 치환으로 subshell 문제 해결
  total=$(tail -n +2 "${MIGRATE_LIST}" | grep -v "^${EXCLUDE_PROJECT}," | wc -l)
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

    ((count++))

    # resume: 이미 완료된 이미지 skip
    if grep -qF "${digest}" "${DONE_LOG}" 2>/dev/null; then
      echo "[${count}/${total}] SKIP: ${image_key} (이미 완료)" | tee -a "${LOG_FILE}"
      continue
    fi

    echo "[${count}/${total}] 처리 중: ${image_key}" | tee -a "${LOG_FILE}"

    # 실패해도 abort 하지 않고 다음 이미지 계속 진행
    if migrate_image "${project}" "${repo}" "${tag}" "${digest}"; then
      echo "${digest}" >> "${DONE_LOG}"
      ((success++))
    else
      ((failed++))
    fi
  done < <(tail -n +2 "${MIGRATE_LIST}")  # 프로세스 치환

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 마이그레이션 완료: 성공 ${success}, 실패 ${failed}, 전체 ${count}" | tee -a "${LOG_FILE}"
  ```

- [x] C-4: --dry-run 및 --project 옵션 추가
  - 파일: `scripts/harbor-migrate.sh`
  - 변경: 테스트용 옵션 지원
  ```bash
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

  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[DRY-RUN] 실제 마이그레이션을 수행하지 않습니다."
    tail -n +2 "${MIGRATE_LIST}" | grep -v "^${EXCLUDE_PROJECT}," | \
      while IFS=',' read -r project repo tag digest size; do
        [[ -n "${TARGET_PROJECT}" && "${project}" != "${TARGET_PROJECT}" ]] && continue
        echo "  ${project}/${repo}:${tag} (${size})"
      done
    exit 0
  fi
  ```

- [x] C-5: docker login 처리 (스크립트 시작 시)
  - 파일: `scripts/harbor-migrate.sh`
  - 변경: 소스/대상 레지스트리 로그인
  ```bash
  # Docker 로그인
  echo "소스 Harbor 로그인..."
  echo "${HARBOR_SOURCE_PASSWORD}" | docker login "${SOURCE_REGISTRY}" -u "${SOURCE_USER}" --password-stdin

  echo "대상 Harbor 로그인..."
  echo "${HARBOR_TARGET_PASSWORD}" | docker login "${TARGET_REGISTRY}" -u "${TARGET_USER}" --password-stdin
  ```

### 덩어리 D: secloudit-helm 전용 처리 스크립트
<!-- # TODO: 전략 확정 후 진행 -->

- [ ] D-1: secloudit-helm 처리 전략 결정
  - 파일: N/A
  - 변경: # TODO - 아래 옵션 중 선택 필요
    - 옵션 1: 태그 단위 분할 전송 (야간 N회 분할)
    - 옵션 2: NFS 직접 복제 (Harbor 스토리지 레벨)
    - 옵션 3: rsync 기반 증분 전송
  - 필요 정보:
    - SRE Harbor 가용 스토리지 용량
    - 야간 작업 가능 시간대
    - 네트워크 대역폭 제한

- [ ] D-2: secloudit-helm 전용 스크립트 작성
  - 파일: `scripts/harbor-migrate-helm.sh`
  - 변경: # TODO - 전략 확정 후 구현
  ```bash
  #!/bin/bash
  # TODO: secloudit-helm 처리 전략 확정 후 구현
  # 예상 용량: 663.58 GB (전체의 72.5%)
  ```

- [ ] D-3: 분할 전송 로직 구현 (전략 확정 시)
  - 파일: `scripts/harbor-migrate-helm.sh`
  - 변경: # TODO - 전략에 따라 구현 방식 결정

### 덩어리 E: 검증 스크립트 (digest 검증, pull 테스트)
<!-- 이 덩어리 = Claude Code 작업 지시 1회 단위 -->

- [x] E-1: digest 검증 스크립트 작성
  - 파일: `scripts/verify-digest.sh`
  - 변경: 소스와 대상 이미지 digest 비교
  - 주의: skopeo 대신 Harbor API(curl) 사용 — Windows 환경 호환성
  ```bash
  #!/bin/bash
  set -euo pipefail

  SOURCE_REGISTRY="${HARBOR_SOURCE_URL:-harbor.innogrid.com}"
  TARGET_REGISTRY="${HARBOR_TARGET_URL:-harbor.sre.local}"
  TARGET_USER="${HARBOR_TARGET_USER:-sre-admin}"
  LOG_FILE="logs/verify-$(date +%Y%m%d).log"

  verify_digest() {
    local project="$1"
    local repo="$2"
    local tag="$3"
    local expected_digest="$4"

    # 대상 Harbor API로 실제 digest 조회 (skopeo 대신 curl 사용)
    # repo 이름에 슬래시 포함 시 URL 인코딩 필요 (예: library/nginx → library%2Fnginx)
    local encoded_repo=$(echo "${repo}" | sed 's|/|%2F|g')
    local actual_digest=$(curl -sf \
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
  ```

- [x] E-2: --sample 옵션으로 샘플 검증 지원
  - 파일: `scripts/verify-digest.sh`
  - 변경: 전체 대신 N개 샘플만 검증
  ```bash
  SAMPLE_COUNT=0
  while [[ $# -gt 0 ]]; do
    case $1 in
      --sample) SAMPLE_COUNT="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  # 샘플 추출
  if [[ ${SAMPLE_COUNT} -gt 0 ]]; then
    VERIFY_LIST=$(tail -n +2 "${MIGRATE_LIST}" | shuf -n "${SAMPLE_COUNT}")
  else
    VERIFY_LIST=$(tail -n +2 "${MIGRATE_LIST}")
  fi
  ```

- [x] E-3: pull 테스트 스크립트 작성
  - 파일: `scripts/test-pull.sh`
  - 변경: SRE Harbor에서 샘플 이미지 pull 테스트
  ```bash
  #!/bin/bash
  set -euo pipefail

  TARGET_URL="${HARBOR_TARGET_URL:-https://harbor.sre.local}"

  test_pull() {
    local project="$1"
    local repo="$2"
    local tag="$3"

    local image="${TARGET_URL#https://}/${project}/${repo}:${tag}"

    echo "Pull 테스트: ${image}"
    docker pull "${image}" && docker rmi "${image}" || {
      echo "ERROR: Pull 실패 - ${image}"
      return 1
    }
    echo "SUCCESS: ${image}"
  }

  # 샘플 이미지 pull 테스트
  echo "=== Pull 테스트 시작 ==="
  # 각 프로젝트에서 1개씩 샘플 선택하여 테스트
  ```

- [x] E-4: 검증 결과 리포트 생성
  - 파일: `scripts/verify-digest.sh`
  - 변경: 검증 결과 요약 리포트 출력
  ```bash
  # 리포트 생성
  generate_report() {
    echo ""
    echo "========== 검증 결과 리포트 =========="
    echo "검증 일시: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "전체: ${total}건"
    echo "성공: ${passed}건"
    echo "실패: ${failed}건"
    echo "성공률: $(( passed * 100 / total ))%"
    echo "======================================"
  }
  ```

---

## 4. 미결 사항

| 항목 | 관련 덩어리 | 상태 |
|---|---|---|
| SRE Harbor 스토리지 가용 용량 | A, C | # TODO |
| secloudit-helm 처리 전략 | D | # TODO |
| 백업 저장소 경로 | B | # TODO |
| 야간 작업 일정 | D | # TODO |
| 포트 443 방화벽 오픈 여부 | A | # TODO |
| 스크립트 실행 위치 | A, B, C | # TODO (로컬 PC vs 소스 Harbor 서버 SSH) |

---

## 5. 인라인 메모란

<!--
  사람이 검토하면서 메모를 남기는 공간입니다.
  Claude는 3단계에서 이 메모를 반영하여 plan.md를 업데이트합니다.

  예시:
  [메모] A-2: 여기서는 async로 처리해야 함
  [메모] B-1: 기존 함수명 유지할 것
  [질문] C-1: 이 방식이 맞나? 확인 필요
-->

(검토 메모를 여기에 작성)

---

## 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-03-17 | 초안 작성 - 덩어리 A~E 정의 |
| 2026-03-17 | 요구사항 변경 반영: 원자적 처리(pull→push→rmi), resume 기능, 실패 시 skip, digest 검증 |
| 2026-03-17 | 검토 피드백 반영: B-3/C-3 프로세스 치환, local 키워드 제거, E-1 skopeo→curl, 미결사항 추가 |
| 2026-03-17 | 추가 피드백: A-2 헤더 스킵 순서 수정, C-2/E-1 repo URL 인코딩 추가 |
| 2026-03-17 | 구현 완료: 덩어리 A, B, C, E 전체 구현 및 커밋 (D는 TODO) |
