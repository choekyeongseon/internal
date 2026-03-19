#!/bin/bash
set -e

# ─────────────────────────────────────────────────────────────────────────────
# ai-workflow-framework 프로젝트 초기화 스크립트
# 사용법: bash init.sh "프로젝트명" [--with-hooks]
# ─────────────────────────────────────────────────────────────────────────────

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 스크립트 위치 기준으로 프레임워크 루트 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$SCRIPT_DIR"

# 인수 파싱
PROJECT_NAME=""
WITH_HOOKS=false

for arg in "$@"; do
    case $arg in
        --with-hooks)
            WITH_HOOKS=true
            ;;
        *)
            if [ -z "$PROJECT_NAME" ]; then
                PROJECT_NAME="$arg"
            fi
            ;;
    esac
done

# 프로젝트명 확인
if [ -z "$PROJECT_NAME" ]; then
    echo -e "${RED}오류: 프로젝트명을 입력하세요.${NC}"
    echo "사용법: bash init.sh \"프로젝트명\" [--with-hooks]"
    exit 1
fi

# 변수 설정
PROJECT_DIR="$FRAMEWORK_ROOT/projects/$PROJECT_NAME"
AI_DIR="$PROJECT_DIR/.ai"
TODAY=$(date +%Y-%m-%d)

# FRAMEWORK_RULES.md에서 버전 읽기
FRAMEWORK_VERSION=$(grep -E "^# version:" "$FRAMEWORK_ROOT/FRAMEWORK_RULES.md" | sed 's/# version: //')
if [ -z "$FRAMEWORK_VERSION" ]; then
    FRAMEWORK_VERSION="2.0.0"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " ai-workflow-framework v$FRAMEWORK_VERSION - 프로젝트 초기화"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# projects/ 폴더 확인 및 생성
if [ ! -d "$FRAMEWORK_ROOT/projects" ]; then
    mkdir -p "$FRAMEWORK_ROOT/projects"
    echo -e "${GREEN}✓${NC} projects/ 폴더 생성됨"
fi

# 이미 존재하는 프로젝트 확인
if [ -d "$PROJECT_DIR" ]; then
    echo -e "${RED}오류: 프로젝트 '$PROJECT_NAME'이(가) 이미 존재합니다.${NC}"
    echo "경로: $PROJECT_DIR"
    exit 1
fi

# 1. 디렉토리 구조 생성
echo ""
echo "[ 1/6 ] 디렉토리 구조 생성"
mkdir -p "$AI_DIR/logs"
mkdir -p "$AI_DIR/skills"
echo -e "${GREEN}✓${NC} $PROJECT_DIR/.ai/ 구조 생성됨"

# 2. 템플릿 파일 복사 및 치환
echo ""
echo "[ 2/6 ] 템플릿 파일 복사"

# 치환 함수
substitute_template() {
    local src="$1"
    local dest="$2"

    sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
        -e "s/{{DATE}}/$TODAY/g" \
        -e "s/{{FRAMEWORK_VERSION}}/$FRAMEWORK_VERSION/g" \
        "$src" > "$dest"
}

# research.md 복사
if [ -f "$FRAMEWORK_ROOT/templates/research.md.template" ]; then
    substitute_template "$FRAMEWORK_ROOT/templates/research.md.template" "$AI_DIR/research.md"
    echo -e "${GREEN}✓${NC} research.md 생성됨"
else
    echo -e "${YELLOW}⚠️${NC} research.md.template 없음 - 건너뜀"
fi

# plan.md 복사
if [ -f "$FRAMEWORK_ROOT/templates/plan.md.template" ]; then
    substitute_template "$FRAMEWORK_ROOT/templates/plan.md.template" "$AI_DIR/plan.md"
    echo -e "${GREEN}✓${NC} plan.md 생성됨"
else
    echo -e "${YELLOW}⚠️${NC} plan.md.template 없음 - 건너뜀"
fi

# progress.md 복사
if [ -f "$FRAMEWORK_ROOT/templates/progress.md.template" ]; then
    substitute_template "$FRAMEWORK_ROOT/templates/progress.md.template" "$AI_DIR/progress.md"
    echo -e "${GREEN}✓${NC} progress.md 생성됨"
else
    echo -e "${YELLOW}⚠️${NC} progress.md.template 없음 - 건너뜀"
fi

# test-report.md 복사
if [ -f "$FRAMEWORK_ROOT/templates/test-report.md.template" ]; then
    substitute_template "$FRAMEWORK_ROOT/templates/test-report.md.template" "$AI_DIR/test-report.md"
    echo -e "${GREEN}✓${NC} test-report.md 생성됨"
else
    echo -e "${YELLOW}⚠️${NC} test-report.md.template 없음 - 건너뜀"
fi

# 세션 로그 템플릿 복사
if [ -f "$FRAMEWORK_ROOT/templates/logs/session.md.template" ]; then
    substitute_template "$FRAMEWORK_ROOT/templates/logs/session.md.template" "$AI_DIR/logs/$TODAY.md"
    echo -e "${GREEN}✓${NC} logs/$TODAY.md 생성됨"
else
    echo -e "${YELLOW}⚠️${NC} session.md.template 없음 - 건너뜀"
fi

# skills/README.md 복사
if [ -f "$FRAMEWORK_ROOT/templates/skills/README.md" ]; then
    cp "$FRAMEWORK_ROOT/templates/skills/README.md" "$AI_DIR/skills/README.md"
    echo -e "${GREEN}✓${NC} skills/README.md 생성됨"
else
    echo -e "${YELLOW}⚠️${NC} skills/README.md 없음 - 건너뜀"
fi

# 3. CLAUDE.md 생성 (FRAMEWORK_RULES.md 내용 삽입)
echo ""
echo "[ 3/6 ] CLAUDE.md 생성 (핵심 규칙 삽입)"

if [ -f "$FRAMEWORK_ROOT/templates/CLAUDE.md.template" ]; then
    # 템플릿의 섹션 1 헤더까지 복사 (1-9줄)
    head -n 9 "$FRAMEWORK_ROOT/templates/CLAUDE.md.template" | \
        sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
            -e "s/{{DATE}}/$TODAY/g" \
            -e "s/{{FRAMEWORK_VERSION}}/$FRAMEWORK_VERSION/g" \
        > "$AI_DIR/CLAUDE.md"

    # FRAMEWORK_RULES.md 내용 삽입 (헤더 3줄 제외)
    echo "" >> "$AI_DIR/CLAUDE.md"
    tail -n +4 "$FRAMEWORK_ROOT/FRAMEWORK_RULES.md" >> "$AI_DIR/CLAUDE.md"

    # 템플릿의 섹션 2, 3 추가 (11줄부터)
    tail -n +11 "$FRAMEWORK_ROOT/templates/CLAUDE.md.template" | \
        sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
            -e "s/{{DATE}}/$TODAY/g" \
            -e "s/{{FRAMEWORK_VERSION}}/$FRAMEWORK_VERSION/g" \
        >> "$AI_DIR/CLAUDE.md"

    echo -e "${GREEN}✓${NC} CLAUDE.md 생성됨 (FRAMEWORK_RULES.md 내용 포함)"
else
    echo -e "${RED}오류: CLAUDE.md.template이 없습니다.${NC}"
    exit 1
fi

# 4. 심볼릭 링크 생성
echo ""
echo "[ 4/6 ] 심볼릭 링크 생성"
ln -s .ai/CLAUDE.md "$PROJECT_DIR/CLAUDE.md"
echo -e "${GREEN}✓${NC} CLAUDE.md → .ai/CLAUDE.md 링크 생성됨"

# 5. Git 초기화
echo ""
echo "[ 5/6 ] Git 초기화"
cd "$PROJECT_DIR"
git init --quiet
git add .
git commit --quiet -m "초기 커밋: ai-workflow-framework v$FRAMEWORK_VERSION 프로젝트 구조 생성"
echo -e "${GREEN}✓${NC} Git 저장소 초기화 및 초기 커밋 완료"

# 6. Hook 설치 (옵션)
echo ""
echo "[ 6/6 ] Hook 설치"
if [ "$WITH_HOOKS" = true ]; then
    if [ -f "$FRAMEWORK_ROOT/hooks/pre-commit" ]; then
        cp "$FRAMEWORK_ROOT/hooks/pre-commit" "$PROJECT_DIR/.git/hooks/pre-commit"
        chmod +x "$PROJECT_DIR/.git/hooks/pre-commit"
        echo -e "${GREEN}✓${NC} pre-commit hook 설치됨"
    else
        echo -e "${YELLOW}⚠️${NC} hooks/pre-commit 없음 - 건너뜀"
    fi
else
    echo -e "${YELLOW}⚠️${NC} --with-hooks 옵션 없음 - 건너뜀"
fi

# 완료 메시지
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✓ 프로젝트 '$PROJECT_NAME' 초기화 완료!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "다음 단계:"
echo "  1. cd projects/$PROJECT_NAME"
echo "  2. claude"
echo "  3. \"CLAUDE.md와 research.md를 읽고 현재 상태를 파악해라\""
echo ""
