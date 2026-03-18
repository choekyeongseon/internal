# ai-workflow-framework v2.0

Claude Code와 협업하기 위한 구조화된 워크플로우 프레임워크.

---

## 핵심 개념

### 상속 구조

```
FRAMEWORK_RULES.md          ← 부모: 모든 프로젝트가 따르는 핵심 규칙
        │
        └── projects/{name}/.ai/CLAUDE.md  ← 자식: 핵심 규칙 포함 + 프로젝트 고유 규칙
```

각 프로젝트의 `.ai/CLAUDE.md`는 두 섹션으로 구분된다:
- **섹션 1**: 프레임워크 핵심 규칙 (수정 금지) — `FRAMEWORK_RULES.md`에서 자동 삽입
- **섹션 2**: 프로젝트 고유 규칙 — 자유롭게 추가/수정 가능
- **섹션 3**: Lazy Loading — 필요 시 로드할 컨텍스트 참조

### 모노레포 구조

모든 프로젝트는 이 레포의 `projects/` 하위에 종속된다. 별도 레포로 분리하지 않는다.

---

## 빠른 시작

```bash
# 프레임워크 루트에서 실행
bash init.sh "프로젝트명"              # 기본
bash init.sh "프로젝트명" --with-hooks # hook 포함

# 프로젝트 디렉토리로 이동
cd projects/프로젝트명

# Claude Code 실행
claude
```

---

## 디렉토리 구조

```
ai-workflow-framework/                  ← 단일 레포 (프레임워크 + 모든 프로젝트)
│
├── FRAMEWORK_RULES.md                  ← 핵심 규칙 단일 출처 (v2.0.0)
├── README.md
├── SETUP.md                            ← 프레임워크 구성 명세
├── init.sh                             ← 프로젝트 초기화 스크립트
│
├── templates/
│   ├── CLAUDE.md.template              ← 두 섹션 구조 + Lazy Loading
│   ├── research.md.template
│   ├── plan.md.template
│   ├── skills/
│   │   ├── README.md                   ← 스킬 문서 작성 가이드
│   │   └── skill.md.template
│   └── logs/
│       └── session.md.template         ← 요청/결과 누적 형식
│
├── hooks/
│   └── pre-commit                      ← Git pre-commit hook
│
└── projects/                           ← 모든 프로젝트가 여기에 종속
    └── {project-name}/
        ├── CLAUDE.md                   ← .ai/CLAUDE.md 심볼릭 링크
        ├── .ai/
        │   ├── CLAUDE.md               ← 핵심 규칙 + 프로젝트 고유 규칙
        │   ├── research.md
        │   ├── plan.md
        │   ├── skills/                 ← 프로젝트별 스킬 문서
        │   └── logs/
        │       └── YYYY-MM-DD.md
        └── ... (실제 코드)
```

---

## v1.0 → v2.0 변경 요약

| 항목 | v1.0 | v2.0 |
|---|---|---|
| 구조 | 단일 CLAUDE.md | 상속 구조 (FRAMEWORK_RULES.md → CLAUDE.md) |
| 레포 | 프로젝트별 분리 | 모노레포 (projects/ 하위 종속) |
| 컨텍스트 | 모든 내용 CLAUDE.md에 포함 | Lazy Loading (skills/ 분리) |
| 자기검증 | 없음 | AI 자기검증 체크리스트 추가 |
| 단계 전환 | 암묵적 | 명시적 전환 조건 |
| 초기화 | 수동 | init.sh 자동화 |
| Hook | 없음 | pre-commit hook 지원 |

---

## 파일별 역할 요약

| 파일 | 성격 | 갱신 주기 |
|---|---|---|
| `FRAMEWORK_RULES.md` | 프레임워크 핵심 규칙 | 프레임워크 버전 업 시 |
| `.ai/CLAUDE.md` | 영구 규칙 (핵심 + 프로젝트) | 규칙 변경 시만 |
| `.ai/research.md` | 읽기 전용에 가깝게 취급 | 새 정보 파악 시 |
| `.ai/plan.md` | 살아있는 문서 | 매 작업 세션 |
| `.ai/logs/YYYY-MM-DD.md` | 누적 기록 | 요청마다 즉시 |
| `.ai/skills/*.md` | 반복 패턴 정리 | 패턴 3회 이상 반복 시 |

---

## 워크플로우 요약

```
[1. 리서치] → [2. 계획 수립] → [3. 계획 검토] → [4. 구현] → [5. 세션 로그]
                                                    ↓ 문제 발생 시
                                               git reset → 2로 복귀
```

자세한 내용은 `FRAMEWORK_RULES.md` 참조.
