#!/bin/bash
# Harbor 마이그레이션 스크립트 - migrate_images.csv의 이미지를 대상 Harbor로 복제

# =============================================================================
# B-1: 스크립트 기본 구조 및 변수 설정
# =============================================================================

SOURCE_HARBOR="harbor.innogrid.com"
SOURCE_USER="sre-user"
SOURCE_PASS="qwe1212!Q"

TARGET_HARBOR="harbor.sre.local"
TARGET_USER="sre-admin"
TARGET_PASS="qwe1212!Q"

MIGRATE_CSV="${MIGRATE_CSV:-all_images.csv}"
DONE_FILE="done_migrate.txt"
FAILED_CSV="failed_migrate.csv"

# 특정 프로젝트만 실행 (비어있으면 전체)
PROJECT_FILTER="${PROJECT_FILTER:-}"

# 결과 카운터
SUCCESS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# =============================================================================
# B-2: 초기화 및 Docker 로그인 (소스 + 대상)
# =============================================================================

# 로그 디렉토리 생성
mkdir -p logs

# 체크포인트 파일 없으면 생성
touch "$DONE_FILE"

# 실패 목록 헤더 (파일 없을 때만)
[ ! -f "$FAILED_CSV" ] && echo "project,repository,tag,digest,error" > "$FAILED_CSV"

# 소스 Harbor 로그인
echo "$SOURCE_PASS" | docker login "$SOURCE_HARBOR" -u "$SOURCE_USER" --password-stdin
if [ $? -ne 0 ]; then
    echo "ERROR: 소스 Harbor 로그인 실패" >&2
    exit 1
fi

# 대상 Harbor 로그인
echo "$TARGET_PASS" | docker login "$TARGET_HARBOR" -u "$TARGET_USER" --password-stdin
if [ $? -ne 0 ]; then
    echo "ERROR: 대상 Harbor 로그인 실패" >&2
    exit 1
fi

echo "마이그레이션 시작: $(date)"
echo "소스: $SOURCE_HARBOR → 대상: $TARGET_HARBOR"
echo "CSV: $MIGRATE_CSV"
[ -n "$PROJECT_FILTER" ] && echo "프로젝트 필터: $PROJECT_FILTER"
echo ""

# =============================================================================
# B-2-5: 대상 Harbor 프로젝트 자동 생성
# =============================================================================

# 프로젝트 목록 추출 (중복 제거)
echo "대상 Harbor 프로젝트 확인 중..."
PROJECTS=$(tail -n +2 "$MIGRATE_CSV" | cut -d',' -f1 | sort -u)

# PROJECT_FILTER 적용
if [ -n "$PROJECT_FILTER" ]; then
    PROJECTS="$PROJECT_FILTER"
fi

for PROJECT in $PROJECTS; do
    # 프로젝트 존재 확인
    HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" \
        -u "$TARGET_USER:$TARGET_PASS" \
        "http://$TARGET_HARBOR/api/v2.0/projects?name=$PROJECT")

    if [ "$HTTP_CODE" = "200" ]; then
        # 응답이 빈 배열인지 확인
        RESULT=$(curl -sk -u "$TARGET_USER:$TARGET_PASS" \
            "http://$TARGET_HARBOR/api/v2.0/projects?name=$PROJECT" | jq 'length')

        if [ "$RESULT" = "0" ]; then
            # 프로젝트 생성 (private)
            curl -sk -X POST \
                -u "$TARGET_USER:$TARGET_PASS" \
                -H "Content-Type: application/json" \
                -d "{\"project_name\":\"$PROJECT\",\"public\":false}" \
                "http://$TARGET_HARBOR/api/v2.0/projects" >/dev/null
            echo "  프로젝트 생성: $PROJECT"
        fi
    fi
done
echo ""

# =============================================================================
# B-3: CSV 읽기 및 이미지 마이그레이션 루프 (체크포인트 + 멀티태그)
# =============================================================================

# CSV 헤더 건너뛰고 처리
tail -n +2 "$MIGRATE_CSV" | while IFS=',' read -r PROJECT REPO TAGS DIGEST SIZE_MB PUSH_TIME PULL_TIME; do
    # 프로젝트 필터 적용
    if [ -n "$PROJECT_FILTER" ] && [ "$PROJECT" != "$PROJECT_FILTER" ]; then
        continue
    fi

    # 체크포인트: 이미 완료된 digest면 건너뛰기
    if grep -qF "$DIGEST" "$DONE_FILE" 2>/dev/null; then
        echo "SKIP (완료됨): $PROJECT/$REPO"
        ((SKIP_COUNT++))
        continue
    fi

    # 태그가 세미콜론으로 구분되어 있으면 분리
    IFS=';' read -ra TAG_ARRAY <<< "$TAGS"
    TAG_SUCCESS=true

    for TAG in "${TAG_ARRAY[@]}"; do
        [ "$TAG" = "<untagged>" ] && continue
        [ -z "$TAG" ] && continue

        SOURCE_IMAGE="$SOURCE_HARBOR/$PROJECT/$REPO:$TAG"
        TARGET_IMAGE="$TARGET_HARBOR/$PROJECT/$REPO:$TAG"

        echo -n "[$(date +%H:%M:%S)] $SOURCE_IMAGE → $TARGET_IMAGE ... "

        # docker pull
        if ! docker pull "$SOURCE_IMAGE" >/dev/null 2>&1; then
            echo "FAIL (pull)"
            echo "$PROJECT,$REPO,$TAG,$DIGEST,pull_failed" >> "$FAILED_CSV"
            ((FAIL_COUNT++))
            TAG_SUCCESS=false
            continue
        fi

        # docker tag
        if ! docker tag "$SOURCE_IMAGE" "$TARGET_IMAGE" 2>/dev/null; then
            echo "FAIL (tag)"
            echo "$PROJECT,$REPO,$TAG,$DIGEST,tag_failed" >> "$FAILED_CSV"
            ((FAIL_COUNT++))
            docker rmi "$SOURCE_IMAGE" >/dev/null 2>&1
            TAG_SUCCESS=false
            continue
        fi

        # docker push
        if ! docker push "$TARGET_IMAGE" >/dev/null 2>&1; then
            echo "FAIL (push)"
            echo "$PROJECT,$REPO,$TAG,$DIGEST,push_failed" >> "$FAILED_CSV"
            ((FAIL_COUNT++))
            docker rmi "$SOURCE_IMAGE" "$TARGET_IMAGE" >/dev/null 2>&1
            TAG_SUCCESS=false
            continue
        fi

        # 로컬 이미지 삭제
        docker rmi "$SOURCE_IMAGE" "$TARGET_IMAGE" >/dev/null 2>&1

        echo "OK"
        ((SUCCESS_COUNT++))
    done

    # 모든 태그 성공 시 체크포인트 기록
    if $TAG_SUCCESS; then
        echo "$DIGEST" >> "$DONE_FILE"
    fi
done

# =============================================================================
# B-4: 결과 요약 출력
# =============================================================================

echo ""
echo "================================"
echo "마이그레이션 완료: $(date)"
echo "  성공: $SUCCESS_COUNT"
echo "  실패: $FAIL_COUNT"
echo "  스킵: $SKIP_COUNT"
echo ""
echo "체크포인트: $DONE_FILE"
[ $FAIL_COUNT -gt 0 ] && echo "실패 목록: $FAILED_CSV"
