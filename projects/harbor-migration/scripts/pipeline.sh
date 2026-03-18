#!/bin/bash
set -a
source "$(dirname "$0")/../.env"
set +a

PLOG="$(dirname "$0")/../logs/pipeline.log"
mkdir -p "$(dirname "$0")/../logs"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${PLOG}"; }

cd "$(dirname "$0")/.."

log "=== 파이프라인 시작 ==="

# 1단계: 분석
log "[1/5] 이미지 분석 시작"
bash scripts/quick-analyze.sh >> "${PLOG}" 2>&1
log "[1/5] 분석 완료 — 마이그레이션: $(tail -n +2 data/migrate_images.csv 2>/dev/null | wc -l)개, 백업: $(tail -n +2 data/backup_images.csv 2>/dev/null | wc -l)개"

# 2단계: SRE Harbor 프로젝트 생성
log "[2/5] SRE Harbor 프로젝트 생성"
bash scripts/create-sre-projects.sh >> "${PLOG}" 2>&1
log "[2/5] 프로젝트 생성 완료"

# 3단계: 백업
log "[3/5] 백업 시작"
bash scripts/harbor-backup.sh >> logs/backup-full-$(date +%Y%m%d_%H%M%S).log 2>&1
log "[3/5] 백업 완료 — $(tail -1 logs/backup-*.log 2>/dev/null | tail -1)"

# 4단계: 마이그레이션 (secloudit-helm 제외)
log "[4/5] 마이그레이션 시작 (secloudit-helm 제외)"
bash scripts/harbor-migrate.sh >> logs/migrate-full-$(date +%Y%m%d_%H%M%S).log 2>&1
log "[4/5] 마이그레이션 완료 — $(tail -1 logs/migrate-full-*.log 2>/dev/null | tail -1)"

# 5단계: 검증
log "[5/5] 검증 시작"
bash scripts/verify-digest.sh --sample 50 >> "${PLOG}" 2>&1
bash scripts/test-pull.sh --sample 10 >> "${PLOG}" 2>&1
log "[5/5] 검증 완료"

log "=== 파이프라인 완료 ==="
