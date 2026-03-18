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

- 프로젝트명: k8s-cluster
- 목적: Terraform(VM 프로비저닝) + Ansible(OS 설정, CRI-O, kubeadm, K8s OSS 설치)으로
  SECloudit PaaS 플랫폼이 올라갈 K8s 클러스터를 자동으로 구축
- 기술스택: Terraform(OpenStack Provider), Ansible, kubeadm, CRI-O
- 주요 제약조건:
    - 고객 환경 전부 폐쇄망 — 인터넷 없이 RPM/이미지 번들로만 설치
    - SECloudit 버전별로 K8s 버전이 다름 — secloudit_version 변수로 분기

### 핵심 변수 (모든 분기의 기준)

```yaml
secloudit_version: v1.5 / v2.0 / v2.3 / v2.6
cluster_type: all-in-one / separated
environment: demo / qa
```

### 레포지토리 구조

```
vm-provision/              ← Terraform: VM 프로비저닝
  modules/k8s-cluster/        ← VM 프로비저닝 모듈
  environments/
    demo/                     ← Demo 환경
    qa/                       ← QA 환경 (workspace: qa-{jira-ticket-id})
  variables.tf

k8s-deploy/                   ← Ansible: K8s 클러스터 구축
  inventories/
    demo/
    qa/
  group_vars/
    all.yaml                  ← k8s_version, crio_version, OSS 버전 변수
    masters.yaml              ← kubeadm 설정값
    haproxy.yaml              ← HAProxy 포트 분기
  roles/
    common/                   ← hostname, /etc/hosts, Harbor CA trust
    k8s-preinstall/           ← SELinux, swap, 커널 모듈, sysctl, firewalld
    k8s-install/              ← CRI-O, kubelet/kubeadm/kubectl RPM 설치
    k8s-init/                 ← kubeadm init/join (idempotency 처리)
    k8s-oss/                  ← Calico, Ingress, NFS, Metrics, Prometheus,
                                ArgoCD, Tekton, Istio, Kafka
  playbooks/
    build-cluster.yaml
  templates/
    kubeadm-config.yaml.j2
```

### 코딩 규칙

**Ansible:**
- 모든 태스크에 name: 필수 (한국어 가능)
- 멱등성 필수 — kubeadm join은 노드 존재 여부 확인 후 skip
- 오프라인 RPM: disable_gpg_check: true, disablerepo: "*"
- 시크릿: 절대 평문 금지, vault_ prefix 변수로만 참조
- ignore_errors: true 는 firewalld 등 없어도 되는 서비스에만 허용

**Terraform:**
- 모든 리소스에 tags 포함 (environment, secloudit_version, cluster_type)
- cluster_type == all-in-one → target_cluster 모듈 count = 0
- workspace 네이밍: demo, qa-{jira-ticket-id} (예: qa-ST-42)
- default 없는 변수는 .tfvars 로만 주입, 하드코딩 금지

**공통:**
- 파일 상단 주석에 역할과 대상 버전 명시
- 버전 분기 로직은 group_vars 에 집중, role 내부 버전 조건문 최소화
- 새 role 추가 시 README.md 작성 (변수 목록, 선행 role 명시)

### 버전별 분기 규칙

**K8s RPM 버전 참조표:**

| secloudit_version | K8s 버전 | RPM 버전 | CRI-O 버전 |
|---|---|---|---|
| v1.5 | 1.23.17 | 1.23.17-0 | 1.23 |
| - | 1.24.14 | 1.24.14-150500.1.1 | 1.24 |
| - | 1.25.10 | 1.25.10-150500.1.1 | 1.25 |
| - | 1.26.11 | 1.26.11-150500.1.1 | 1.26 |
| v2.0 | 1.27.8 | 1.27.8-150500.1.1 | 1.27 |

**HAProxy 포트 분기:**
```yaml
haproxy_api_frontend_port: "{{ '26443' if secloudit_version == 'v1.5' else '6443' }}"
haproxy_http_nodeport:     "{{ '30180' if secloudit_version == 'v1.5' else '30080' }}"
haproxy_https_nodeport:    "{{ '30181' if secloudit_version == 'v1.5' else '30443' }}"
```

**K8s OSS 설치 순서 (변경 금지):**
```
Calico → Ingress → NFS Provisioner → Metrics Server
→ Prometheus → ArgoCD → Tekton → Istio → Kafka
```

### 주요 주의사항

- kubeadm 토큰 TTL 24시간 → 재실행 시 만료 → idempotency 처리 필수
- Calico: Master init 직후, Worker join 이전에 설치
- Metrics Server: --kubelet-insecure-tls + hostNetwork: true 패치 필수
- ArgoCD HA: 워커 3대 미만 시 podAntiAffinity 제거 패치 필요
- Harbor 인증서: 모든 노드에 CA trust 등록 (update-ca-trust)

### 미확인 항목

# TODO: 확인 전까지 임의 결정 금지
- v2.0 / v2.3 현장 K8s 버전 (RPM 버전 확인 필요)
- v2.6 K8s 버전
- demo / qa 클러스터 노드 수 및 사양 (OpenStack flavor 이름 포함)
- OpenStack 네트워크 이름 / 이미지 이름 (환경별 다름)
- QA 클러스터 수명 관리 방식 (TTL vs 수동 destroy)
- Jira 티켓 필드 정의 (버전, 패턴 선택 필드명)

### 참고 문서

- 리서치 산출물: `.ai/research.md`
- 구현 계획: `.ai/plan.md`
- 세션 로그: `.ai/logs/`
- 스킬 문서: `.ai/skills/`
- SECloudit 환경 파악: https://pms-innogrid.atlassian.net/wiki/spaces/~71202045fdda26b1ce47eb897d2c53a347e25d/pages/1793294409
- K8s 클러스터 구축 자동화 수집 정보: https://pms-innogrid.atlassian.net/wiki/spaces/~71202045fdda26b1ce47eb897d2c53a347e25d/pages/1793228889

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
