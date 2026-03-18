---
## ── 프레임워크 핵심 규칙 ───────────────────────────────────────
<!--
  ⚠️  이 섹션은 수정하지 마세요.
  출처: ai-workflow-framework/FRAMEWORK_RULES.md v2.0.0
  규칙 변경이 필요하면 루트의 FRAMEWORK_RULES.md를 수정하세요.
  init.sh 실행 시 이 섹션에 FRAMEWORK_RULES.md 내용이 자동 삽입됩니다.
-->
---


---

## 1. 워크플로우 (5단계)

```
[1. 리서치] → [2. 계획 수립] → [3. 계획 검토] → [4. 구현] → [5. 세션 로그]
                                                    ↓ 문제 발생 시
                                               git reset → 2로 복귀
```

---

## 2. 핵심 명령 모음

| 단계 | Claude에게 하는 말 |
|---|---|
| 시작 | `"CLAUDE.md와 research.md를 읽고 현재 상태를 파악해라"` |
| 1단계 | `"[범위]를 분석해서 research.md에 작성해라. 아직 구현하지 마라"` |
| 2단계 | `"research.md를 읽고 plan.md를 작성해라. 아직 구현하지 마라"` |
| 3단계 | `"메모를 반영해서 plan.md를 업데이트해라. 아직 구현하지 마라"` |
| 4단계 | `"덩어리 A를 구현해라. 계획에 없는 변경은 하지 마라. 각 항목 완료 시 커밋해라"` |
| 롤백 | `git reset --hard HEAD~1` 후 plan.md 재검토 |
| 5단계 | `"세션 로그 #N을 기록해라"` |

---

## 3. 핵심 원칙 (5가지)

1. **계획 전에 구현하지 않는다** — "아직 구현하지 마라" 문구 매번 명시
2. **체크리스트 항목 1개 = Git 커밋 1개** — 롤백 비용 최소화
3. **미확인 항목은 `# TODO:`로만 표시** — 임의 결정 금지
4. **세션 로그는 요청마다 즉시, 짧게** — 요청/결과를 한 줄씩 누적
5. **외부 문서 도구는 마일스톤 완료 시에만** — 매 세션 업데이트는 관리 비용 낭비

---

## 4. AI 자기검증 체크리스트

매 단계 완료 시 아래 항목을 스스로 확인한다. 하나라도 실패하면 해당 단계를 다시 수행한다.

### 1단계 완료 시:
- [ ] A1-1: 결과를 `research.md` 파일로 출력했는가?
- [ ] A1-2: 파일/폴더 구조, 모듈 역할, 의존성 관계를 포함했는가?
- [ ] A1-3: 제약사항(환경, 호환성, 보안)을 식별했는가?
- [ ] A1-4: 변경 시 영향 범위(사이드이펙트)를 명시했는가?
- [ ] A1-5: 코드를 수정하거나 생성하지 않았는가?

### 2단계 완료 시:
- [ ] A2-1: `research.md`를 읽고 시작했는가?
- [ ] A2-2: 변경 이유/목표가 명확히 기술되어 있는가?
- [ ] A2-3: 수정/생성할 파일 경로가 구체적으로 나열되어 있는가?
- [ ] A2-4: 각 변경에 코드 스니펫 수준의 상세 설명이 있는가?
- [ ] A2-5: 트레이드오프가 분석되어 있는가? (선택지가 있는 경우)
- [ ] A2-6: 체크리스트가 덩어리(A/B/C) 단위로 그룹화되어 있는가?
- [ ] A2-7: 결과를 `plan.md` 파일로 출력했는가?
- [ ] A2-8: 코드를 수정하거나 생성하지 않았는가?

### 3단계 완료 시 (메모 반영):
- [ ] A3-1: 사람의 인라인 메모를 모두 반영했는가?
- [ ] A3-2: 메모에 없는 내용을 임의로 추가하지 않았는가?
- [ ] A3-3: `plan.md` 파일에 반영했는가?
- [ ] A3-4: 코드를 수정하거나 생성하지 않았는가?

### 4단계 완료 시:
- [ ] A4-1: `plan.md`의 체크리스트 항목만 구현했는가?
- [ ] A4-2: `plan.md`에 명시된 파일만 수정/생성했는가?
- [ ] A4-3: 체크리스트 항목 1개당 Git 커밋 1개를 만들었는가?
- [ ] A4-4: "개선", "리팩토링", "최적화"를 임의로 추가하지 않았는가?
- [ ] A4-5: 미확인 항목은 `# TODO:`로만 표시하고 임의 결정하지 않았는가?

### 5단계 완료 시:
- [ ] A5-1: 요청/결과를 각각 한 줄로 기록했는가?
- [ ] A5-2: 로그를 `.ai/logs/YYYY-MM-DD.md` 파일에 기록했는가?
- [ ] A5-3: 세션 종료 메모 3항목(루프/오류/개선점)을 포함했는가?

---

## 5. 단계 전환 조건

| 전환 | 통과 조건 | 차단 조건 |
|---|---|---|
| 1→2 | `research.md` 존재 + 자기검증 통과 | 사실 오류 미수정, 코드 변경 발생 |
| 2→3 | `plan.md` 존재 + 5가지 항목 포함 + 코드 변경 없음 | 항목 누락, 코드 수정 발생 |
| 3→4 | 사람이 `plan.md` 직접 검토 + 승인 | 미검토, 잘못된 가정 미수정 |
| 4→5 | 모든 체크리스트 완료 + 테스트 통과 + 계획 외 변경 없음 | 테스트 실패, Scope Creep 존재 |
| 역방향 | 4→3: `git reset`, 3→1: 리서치 부실 | — |

---

## 6. 세션 로그 형식

요청마다 즉시 누적한다:

```markdown
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

---

## 7. 파일 역할 요약

| 파일 | 성격 | 갱신 주기 |
|---|---|---|
| `.ai/CLAUDE.md` | 영구 규칙 | 규칙 변경 시만 |
| `.ai/research.md` | 읽기 전용에 가깝게 취급 | 새 정보 파악 시 |
| `.ai/plan.md` | 살아있는 문서 | 매 작업 세션 |
| `.ai/logs/YYYY-MM-DD.md` | 누적 기록 | 요청마다 즉시 |
| `.ai/skills/*.md` | 반복 패턴 정리 | 패턴 3회 이상 반복 시 |
---
## ── 프로젝트 고유 규칙 ───────────────────────────────────────
<!--
  ✏️  이 섹션을 프로젝트에 맞게 채우세요.
  핵심 규칙과 충돌하지 않는 범위에서 자유롭게 추가/수정 가능합니다.
-->
---

### 프로젝트 개요
- 프로젝트명: secloudit-v1.5
- 목적: SECloudit v1.5 솔루션 컴포넌트를 각 VM에 podman-compose로 배포하고,
        K8s 클러스터 안에 FluentD Agent / Tekton을 kubectl apply로 배포
- 기술스택: Ansible, Podman, podman-compose
- 선행 조건: k8s-cluster 프로젝트 완료 (K8s 클러스터 구축 + Harbor 이미지 로드 완료 상태)
- 핵심 개념:
  - SECloudit 솔루션 컴포넌트는 K8s 클러스터 안에 올라가는 게 아님
  - K8s 클러스터는 SECloudit이 관리하는 대상, SECloudit이 돌아가는 곳이 아님
  - 솔루션 VM(SE노드, Logging노드, Image Registry)에 직접 컨테이너로 배포

### 배포 구조

```
[VM 배포 — podman-compose]
Image Registry VM   : docker-registry (port 5000) + docker-registry-web (port 8080)
SE 노드 VM          : MySQL (port 3306) → SECloudit Console (port 9080)
Logging VM          : MongoDB (port 27017) → FluentD Forward (port 24224)

[in-cluster 배포 — kubectl apply]
FluentD Agent       : DaemonSet (각 K8s 노드에서 로그 수집 → Logging VM 전달)
Tekton Pipelines    : v0.28.3
Tekton Triggers     : v0.18.0
```

> Image Registry: Harbor(v2.7.1) 또는 docker-registry(v15.0.2) 선택
> v1.5는 Harbor 미사용이 기본. docker-registry (port 5000) + docker-registry-web 조합.

### OSS 버전 (v1.5 기준)

| 컴포넌트 | 버전 |
|---|---|
| Kubernetes | 1.19.16 ~ 1.23.8 (현장별 상이, 우리 환경: 1.23.17) |
| Tekton Pipeline | 0.28.3 |
| Tekton Listener (Triggers) | 0.18.0 |
| Prometheus | 2.20.0 |
| FluentD | 1.13 |
| MySQL | 8.0.31 |
| MongoDB | 5.0.14 |
| docker-registry | 15.0.2 |
| Harbor (선택) | 2.7.1 |

### 레포지토리 구조

```
secloudit-v1.5/
├── inventories/
│   ├── demo/hosts.yaml       ← SE노드, Logging노드, Image Registry, K8s Master
│   └── qa/hosts.yaml
├── group_vars/
│   └── all.yaml              ← 공통 변수 (이미지 레지스트리 주소, 버전, 시크릿 참조)
├── roles/
│   ├── docker-registry/      ← docker-registry + docker-registry-web (podman-compose)
│   ├── secloudit-console/    ← MySQL → SECloudit Console (podman-compose)
│   ├── secloudit-logging/    ← MongoDB → FluentD Forward (podman-compose)
│   ├── fluentd-agent/        ← in-cluster FluentD DaemonSet (kubectl apply)
│   └── tekton/               ← Tekton Pipelines + Triggers (kubectl apply)
└── playbooks/
    └── deploy-secloudit.yaml
```

### 설치 순서 (변경 금지)

```
1. Image Registry VM  — docker-registry 구동 (이미지 저장소 먼저)
2. SE 노드 VM         — MySQL 구동 → healthy 확인 → SECloudit Console 구동
3. Logging VM         — MongoDB 구동 → FluentD Forward 구동
4. in-cluster         — FluentD Agent DaemonSet 배포 (K8s Master에서 kubectl apply)
5. in-cluster         — Tekton Pipelines(v0.28.3) → Tekton Triggers(v0.18.0) 배포
```

### 코딩 규칙
- Ansible: 모든 태스크에 name: 필수
- 멱등성 필수 — podman ps로 컨테이너 존재 여부 확인 후 skip
- 시크릿: 절대 평문 금지, vault_ prefix 변수로만 참조
- podman-compose: 이미지 사전 로드 여부 확인 후 up -d 실행
- docker-compose.yaml은 templates/ 에서 Jinja2(.j2)로 관리
- in-cluster 태스크: kubectl apply 전 kubeconfig 경로 확인 필수

### 시크릿 항목 (값 기재 금지)
- vault_mysql_root_password
- vault_mongodb_root_password
- vault_registry_password (docker-registry htpasswd)
- vault_secloudit_admin_password

### 미확인 항목
# TODO: 확인 전까지 임의 결정 금지
- Image Registry: docker-registry vs Harbor 현장별 선택 기준
- SE 노드와 Image Registry 노드 통합 여부
- FluentD Agent FLUENT_FOWARD_HOST 값 (Logging VM IP)
- FluentD CLUSTER_DIVIDE_VALUE (클러스터 구분자)
- httpd https proxy 인증서 경로 및 설정값
- Tekton manifest의 이미지 레지스트리 주소 (SEClouditREG → 실제 주소로 치환 필요)

### 참고 문서
- 리서치 산출물: `.ai/research.md`
- 구현 계획: `.ai/plan.md`
- 세션 로그: `.ai/logs/`
- 스킬 문서: `.ai/skills/`

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
