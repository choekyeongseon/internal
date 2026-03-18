# SETUP.md — ai-workflow-framework v2.0 구성 요청

> 이 파일을 읽은 Claude Code는 아래 지시에 따라 프레임워크를 처음부터 구성한다.
> **아직 구현하지 마라. 이 파일 전체를 읽은 후 계획을 먼저 말하고 승인을 기다려라.**

---

## 개념 이해 (구현 전 반드시 읽기)

### 핵심 구조 1 — 상속

```
FRAMEWORK_RULES.md          ← 부모: 모든 프로젝트가 따르는 핵심 규칙
        │
        └── projects/{name}/.ai/CLAUDE.md  ← 자식: 핵심 규칙 포함 + 프로젝트 고유 규칙
```

각 프로젝트의 `.ai/CLAUDE.md` 는 두 섹션으로 명확히 구분된다:

```
## ── 프레임워크 핵심 규칙 (수정 금지) ──
# 출처: ai-workflow-framework/FRAMEWORK_RULES.md v2.0.0
# 수정하지 마라. 프레임워크 레포에서 FRAMEWORK_RULES.md를 수정하라.

## ── 프로젝트 고유 규칙 ──
# 이 프로젝트에만 적용되는 규칙. 자유롭게 추가/수정 가능.
```

### 핵심 구조 2 — 모노레포

모든 프로젝트는 이 레포의 `projects/` 하위에 종속된다. 별도 레포로 분리하지 않는다.

---

## 최종 디렉토리 구조

```
ai-workflow-framework/                  ← 단일 레포 (프레임워크 + 모든 프로젝트)
│
├── FRAMEWORK_RULES.md                  ← 핵심 규칙 단일 출처 (v2.0.0)
├── README.md
├── SETUP.md                            ← 이 파일
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

## 파일별 명세

---

### 1. `FRAMEWORK_RULES.md`

버전 헤더 (최상단):
```
# FRAMEWORK_RULES.md
# version: 2.0.0
# 변경 시 projects/ 하위 모든 프로젝트의 CLAUDE.md 핵심 섹션 업데이트 필요
```

포함 내용 (순서대로):

#### 1-1. 워크플로우 (5단계)

```
[1. 리서치] → [2. 계획 수립] → [3. 계획 검토] → [4. 구현] → [5. 세션 로그]
                                                    ↓ 문제 발생 시
                                               git reset → 2로 복귀
```

#### 1-2. 핵심 명령 모음 표

| 단계 | Claude에게 하는 말 |
|---|---|
| 시작 | `"CLAUDE.md와 research.md를 읽고 현재 상태를 파악해라"` |
| 1단계 | `"[범위]를 분석해서 research.md에 작성해라. 아직 구현하지 마라"` |
| 2단계 | `"research.md를 읽고 plan.md를 작성해라. 아직 구현하지 마라"` |
| 3단계 | `"메모를 반영해서 plan.md를 업데이트해라. 아직 구현하지 마라"` |
| 4단계 | `"덩어리 A를 구현해라. 계획에 없는 변경은 하지 마라. 각 항목 완료 시 커밋해라"` |
| 롤백 | `git reset --hard HEAD~1` 후 plan.md 재검토 |
| 5단계 | `"세션 로그 #N을 기록해라"` |

#### 1-3. 핵심 원칙 (5가지)

1. **계획 전에 구현하지 않는다** — "아직 구현하지 마라" 문구 매번 명시
2. **체크리스트 항목 1개 = Git 커밋 1개** — 롤백 비용 최소화
3. **미확인 항목은 `# TODO:`로만 표시** — 임의 결정 금지
4. **세션 로그는 요청마다 즉시, 짧게** — 요청/결과를 한 줄씩 누적
5. **외부 문서 도구는 마일스톤 완료 시에만** — 매 세션 업데이트는 관리 비용 낭비

#### 1-4. AI 자기검증 체크리스트

매 단계 완료 시 아래 항목을 스스로 확인한다. 하나라도 실패하면 해당 단계를 다시 수행한다.

**1단계 완료 시:**
- [ ] A1-1: 결과를 `research.md` 파일로 출력했는가?
- [ ] A1-2: 파일/폴더 구조, 모듈 역할, 의존성 관계를 포함했는가?
- [ ] A1-3: 제약사항(환경, 호환성, 보안)을 식별했는가?
- [ ] A1-4: 변경 시 영향 범위(사이드이펙트)를 명시했는가?
- [ ] A1-5: 코드를 수정하거나 생성하지 않았는가?

**2단계 완료 시:**
- [ ] A2-1: `research.md`를 읽고 시작했는가?
- [ ] A2-2: 변경 이유/목표가 명확히 기술되어 있는가?
- [ ] A2-3: 수정/생성할 파일 경로가 구체적으로 나열되어 있는가?
- [ ] A2-4: 각 변경에 코드 스니펫 수준의 상세 설명이 있는가?
- [ ] A2-5: 트레이드오프가 분석되어 있는가? (선택지가 있는 경우)
- [ ] A2-6: 체크리스트가 덩어리(A/B/C) 단위로 그룹화되어 있는가?
- [ ] A2-7: 결과를 `plan.md` 파일로 출력했는가?
- [ ] A2-8: 코드를 수정하거나 생성하지 않았는가?

**3단계 완료 시 (메모 반영):**
- [ ] A3-1: 사람의 인라인 메모를 모두 반영했는가?
- [ ] A3-2: 메모에 없는 내용을 임의로 추가하지 않았는가?
- [ ] A3-3: `plan.md` 파일에 반영했는가?
- [ ] A3-4: 코드를 수정하거나 생성하지 않았는가?

**4단계 완료 시:**
- [ ] A4-1: `plan.md`의 체크리스트 항목만 구현했는가?
- [ ] A4-2: `plan.md`에 명시된 파일만 수정/생성했는가?
- [ ] A4-3: 체크리스트 항목 1개당 Git 커밋 1개를 만들었는가?
- [ ] A4-4: "개선", "리팩토링", "최적화"를 임의로 추가하지 않았는가?
- [ ] A4-5: 미확인 항목은 `# TODO:`로만 표시하고 임의 결정하지 않았는가?

**5단계 완료 시:**
- [ ] A5-1: 요청/결과를 각각 한 줄로 기록했는가?
- [ ] A5-2: 로그를 `.ai/logs/YYYY-MM-DD.md` 파일에 기록했는가?
- [ ] A5-3: 세션 종료 메모 3항목(루프/오류/개선점)을 포함했는가?

#### 1-5. 단계 전환 조건

| 전환 | 통과 조건 | 차단 조건 |
|---|---|---|
| 1→2 | `research.md` 존재 + 자기검증 통과 | 사실 오류 미수정, 코드 변경 발생 |
| 2→3 | `plan.md` 존재 + 5가지 항목 포함 + 코드 변경 없음 | 항목 누락, 코드 수정 발생 |
| 3→4 | 사람이 `plan.md` 직접 검토 + 승인 | 미검토, 잘못된 가정 미수정 |
| 4→5 | 모든 체크리스트 완료 + 테스트 통과 + 계획 외 변경 없음 | 테스트 실패, Scope Creep 존재 |
| 역방향 | 4→3: `git reset`, 3→1: 리서치 부실 | — |

#### 1-6. 세션 로그 형식

요청마다 즉시 누적한다:

```
## #1
요청: [요청 내용 한 줄]
결과: [작업 결과 한 줄]

## #2
요청: ...
결과: ...

## 세션 종료 메모
- 루프가 돌았던 순간:
- Claude가 틀린 경우:
- 다음에 개선할 것:
```

#### 1-7. 파일 역할 요약

| 파일 | 성격 | 갱신 주기 |
|---|---|---|
| `.ai/CLAUDE.md` | 영구 규칙 | 규칙 변경 시만 |
| `.ai/research.md` | 읽기 전용에 가깝게 취급 | 새 정보 파악 시 |
| `.ai/plan.md` | 살아있는 문서 | 매 작업 세션 |
| `.ai/logs/YYYY-MM-DD.md` | 누적 기록 | 요청마다 즉시 |
| `.ai/skills/*.md` | 반복 패턴 정리 | 패턴 3회 이상 반복 시 |

---

### 2. `README.md`

포함 내용:
- 프레임워크 목적 (한 문장)
- 핵심 개념: 상속 구조 + 모노레포 다이어그램
- 빠른 시작:
  ```bash
  bash init.sh "프로젝트명"           # 기본
  bash init.sh "프로젝트명" --with-hooks  # hook 포함
  cd projects/프로젝트명
  claude
  ```
- 전체 디렉토리 구조 (위 구조 그대로)
- v1.0 → v2.0 변경 요약 표
- 파일별 역할 요약 표

---

### 3. `init.sh`

동작:
1. `projects/{project-name}/` 및 `.ai/logs/`, `.ai/skills/` 생성
2. `templates/` 파일들을 `.ai/` 로 복사하며 치환:
    - `{{PROJECT_NAME}}` → 스크립트 인수
    - `{{DATE}}` → 오늘 날짜 (`YYYY-MM-DD`)
    - `{{FRAMEWORK_VERSION}}` → `FRAMEWORK_RULES.md` 버전 헤더에서 자동 읽기
3. `FRAMEWORK_RULES.md` 내용을 `CLAUDE.md` 섹션 1에 삽입
4. `projects/{project-name}/CLAUDE.md → .ai/CLAUDE.md` 심볼릭 링크 생성
5. `projects/{project-name}/` 에서 `git init` + 초기 커밋
6. `--with-hooks` 옵션 시: `hooks/pre-commit` → `.git/hooks/pre-commit` 설치

사용법:
```bash
# 프레임워크 루트에서 실행
bash init.sh "프로젝트명"
bash init.sh "프로젝트명" --with-hooks
```

요구사항:
- `set -e`
- `projects/` 폴더가 없으면 자동 생성
- 이미 존재하는 프로젝트면 오류 출력 후 중단
- 각 단계 콘솔 출력 (`✓ 생성됨`, `⚠️ 건너뜀`)
- 완료 후 다음 단계 3가지 안내
- macOS / Linux 모두 동작 (`bash` 기준)

---

### 4. `templates/CLAUDE.md.template`

두 섹션 구조를 반드시 지킨다.

**섹션 1 헤더:**
```markdown
---
## ── 프레임워크 핵심 규칙 ───────────────────────────────────────
<!--
  ⚠️  이 섹션은 수정하지 마세요.
  출처: ai-workflow-framework/FRAMEWORK_RULES.md v{{FRAMEWORK_VERSION}}
  규칙 변경이 필요하면 루트의 FRAMEWORK_RULES.md를 수정하세요.
  init.sh 실행 시 이 섹션에 FRAMEWORK_RULES.md 내용이 자동 삽입됩니다.
-->
---
[FRAMEWORK_RULES.md 내용 자동 삽입 위치]
```

**섹션 2 헤더 + 내용:**
```markdown
---
## ── 프로젝트 고유 규칙 ───────────────────────────────────────
<!--
  ✏️  이 섹션을 프로젝트에 맞게 채우세요.
  핵심 규칙과 충돌하지 않는 범위에서 자유롭게 추가/수정 가능합니다.
-->
---

### 프로젝트 개요
- 프로젝트명: {{PROJECT_NAME}}
- 목적:
- 기술스택:
- 주요 제약 조건:

### 레포지토리 구조
(프로젝트 구조로 교체)

### 코딩 규칙
(언어/도구별 컨벤션)

### 미확인 항목
# TODO: 확인 전까지 임의 결정 금지
- 

### 참고 문서
- 리서치 산출물: `.ai/research.md`
- 구현 계획: `.ai/plan.md`
- 세션 로그: `.ai/logs/`
- 스킬 문서: `.ai/skills/`
```

**섹션 3 — Lazy Loading (v2.0 신규):**
```markdown
---
## ── 컨텍스트 관리 (Lazy Loading) ───────────────────────────────
<!--
  CLAUDE.md에는 참조 링크만 둔다. 상세 내용은 별도 파일로 분리한다.
  Claude가 필요할 때만 해당 파일을 읽게 하여 토큰 낭비를 방지한다.
-->
---

### Context 레이어 구분

| 레이어 | 파일 | 역할 |
|---|---|---|
| System (불변 규칙) | 이 CLAUDE.md | 워크플로우, 핵심 원칙, 프로젝트 규칙 |
| Environment (분석 데이터) | `.ai/research.md` | 코드베이스 분석 결과 |
| Plan (실행 계획) | `.ai/plan.md` | 현재 작업의 상세 계획 |
| Skills (베스트 프랙티스) | `.ai/skills/*.md` | 작업 유형별 패턴과 규칙 |

### 상세 컨텍스트 참조 (필요 시 로드)
- 프로젝트별 스킬: `.ai/skills/` 디렉토리 참조
- 필요할 때: `"skills/파일명.md를 읽고 시작해라"` 로 로드

### 참조 규칙
1. 이 CLAUDE.md는 매 세션 자동 로드됨 — 여기에는 핵심만 둔다
2. 상세 내용은 `skills/` 또는 별도 파일에 분리한다
3. 프로젝트가 커지면 폴더별 CLAUDE.md 분리를 검토한다
```

---

### 5. `templates/research.md.template`

포함 섹션:
1. 헤더 (작성일 `{{DATE}}`, 상태: `진행 중`, 목적 한 줄)
2. **자동화/구현 대상** — 무엇을 만드는가 + 핵심 제약 조건
3. **기술 스택 및 버전** — 표 (항목/버전/비고)
4. **아키텍처 / 구성 파악** — 자유 서술
5. **핵심 변수 / 설정값** — yaml 코드블록 예시 포함
6. **의존성 및 순서** — 자유 서술
7. **시크릿 / 접속 정보 항목 목록** — 표, "값 기재 금지" 안내
8. **변경 영향 범위** — 사이드이펙트 체크 항목
9. **미확인 항목** — 표 (항목/영향 범위/확인 방법)

---

### 6. `templates/plan.md.template`

포함 섹션:
1. 헤더 (작성일 `{{DATE}}`, 상태: `검토 중 → 구현 전 "구현 중"으로 변경`, 현재 Phase)
2. **목표** — 한 문장 + 성공 기준 체크리스트
3. **트레이드오프** — 표 (결정/선택/이유)
4. **구현 체크리스트** — 덩어리 A/B/C 그룹화
    - 각 항목 `- [ ]` 형식
    - 덩어리 헤더 아래 `<!-- 이 덩어리 = Claude Code 작업 지시 1회 단위 -->` 주석
5. **미결 사항** — 표 (항목/관련 덩어리)
6. **인라인 메모란** — HTML 주석으로 예시 포함

---

### 7. `templates/skills/README.md`

포함 내용:
- 스킬(Skill)이란 무엇인가
- 스킬 문서를 만드는 시점 (세션 로그에서 패턴 3회 이상 반복)
- 발전 경로: 세션 로그 패턴 → FRAMEWORK_RULES.md 규칙 → 스킬 문서 분리
- 사용법 (CLAUDE.md Lazy Loading 섹션에 추가하는 방법)

---

### 8. `templates/skills/skill.md.template`

포함 섹션:
1. 헤더 (`{{SKILL_NAME}}`, 적용 대상, 발견 경로, 반복 횟수)
2. **규칙** — 필수 / 권장 / 금지 세 카테고리
3. **코드 패턴 예시** — 좋은 예시 vs 나쁜 예시
4. **관련 스킬** — 다른 스킬 문서 참조

---

### 9. `templates/logs/session.md.template`

포함 섹션:
1. 헤더 (날짜, 프로젝트명, 해당 Phase)
2. **요청/결과 누적 로그** — `## #N` 형식
   ```
   ## #1
   요청:
   결과:
   ```
   (이후 반복)
3. **세션 종료 메모** — 루프가 돌았던 순간 / Claude가 틀린 경우 / 다음에 개선할 것

---

### 10. `hooks/pre-commit`

동작:
1. `.ai/plan.md` 존재 여부 경고 (없어도 차단하지 않음, 경고만)
2. `test.sh` 존재 시 실행 → 실패 시 커밋 차단
3. `lint.sh` 존재 시 실행 → 실패 시 커밋 차단

실행 권한: `chmod +x hooks/pre-commit`

---

## 구현 규칙

- 모든 파일 한국어 작성 (주석, 안내 문구 포함)
- placeholder 형식: `{{UPPER_SNAKE_CASE}}`
- template 파일은 빈 항목 없이 예시 포함 — 바로 사용 가능한 수준
- 구현 순서:
    1. `FRAMEWORK_RULES.md`
    2. `README.md`
    3. `init.sh`
    4. `templates/CLAUDE.md.template`
    5. `templates/research.md.template`
    6. `templates/plan.md.template`
    7. `templates/skills/README.md`
    8. `templates/skills/skill.md.template`
    9. `templates/logs/session.md.template`
    10. `hooks/pre-commit`
- 각 파일 완성 후 한 줄 보고 후 다음으로 이동

---

## 완료 기준

- [ ] `FRAMEWORK_RULES.md` — v2.0.0 버전 헤더, AI 자기검증 체크리스트, 단계 전환 조건 포함
- [ ] `README.md` — 모노레포 + 상속 구조 다이어그램 포함
- [ ] `init.sh` — `projects/` 하위 생성, `--with-hooks` 옵션, `git init` + 초기 커밋
- [ ] `templates/CLAUDE.md.template` — 3섹션 (핵심규칙/고유규칙/Lazy Loading)
- [ ] `templates/research.md.template` — 9개 섹션, 예시 포함
- [ ] `templates/plan.md.template` — 덩어리 그룹화, 메모란 포함
- [ ] `templates/skills/README.md`
- [ ] `templates/skills/skill.md.template`
- [ ] `templates/logs/session.md.template` — 요청/결과 누적 형식
- [ ] `hooks/pre-commit` — 실행 권한 포함
- [ ] `init.sh` 테스트:
    - `bash init.sh test-project` 실행
    - `projects/test-project/.ai/` 구조 확인
    - 생성된 `CLAUDE.md` 3섹션 경계 확인
    - `FRAMEWORK_RULES.md` 내용이 섹션 1에 삽입됐는지 확인
    - 테스트 완료 후 `projects/test-project/` 삭제

---

## 시작 전 확인 사항

구현 전 아래를 확인하고 답해라:

1. 현재 작업 디렉토리 경로
2. 이미 존재하는 파일 여부
3. 위 명세에서 불명확한 부분

확인 후 아래 형식으로 계획을 말하고 승인을 기다려라:

```
계획:
1. FRAMEWORK_RULES.md — [내용 한 줄]
2. README.md — [내용 한 줄]
3. init.sh — [내용 한 줄]
4. templates/CLAUDE.md.template — [내용 한 줄]
5. templates/research.md.template — [내용 한 줄]
6. templates/plan.md.template — [내용 한 줄]
7. templates/skills/README.md — [내용 한 줄]
8. templates/skills/skill.md.template — [내용 한 줄]
9. templates/logs/session.md.template — [내용 한 줄]
10. hooks/pre-commit — [내용 한 줄]
11. init.sh 테스트 실행

승인하시면 구현을 시작하겠습니다.
```