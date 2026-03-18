아래 순서대로 진행해라.
아직 구현하지 마라. 각 단계 완료 후 결과를 보고하고 다음 단계로 넘어가라.

---

## 1단계 — 프로젝트 초기화

프레임워크 루트에서 실행: (이미 진행완료)

완료 후 생성된 구조를 보고해라.

---

## 2단계 — CLAUDE.md 섹션 2 채우기

projects/secloudit-v2.3/.ai/CLAUDE.md 의 섹션 2를 아래 내용으로 채워라.
섹션 1은 절대 수정하지 마라.

### 프로젝트 개요
- 프로젝트명: secloudit-v2.3
- 목적: SECloudit v2.3 솔루션 컴포넌트를 각 VM에 docker-compose로 배포하고,
        K8s 클러스터 안에 OSS를 kubectl apply로 배포
- 기술스택: Ansible, Docker, docker-compose
- 선행 조건: k8s-cluster 프로젝트 완료 (K8s 클러스터 구축 완료)
- 이미지 레지스트리: sample.harbor.com (모든 프로젝트 공통)

### v2.0 대비 핵심 변경사항
- Keycloak 신규: innogrid-auth VM 추가 (Keycloak + MySQL for Keycloak)
- DevOpsit 이관: GitLab, Harbor, ArgoCD → DevOpsit이 관리 (우리 자동화 범위 아님)
- Tekton: 메뉴에서 제거 (패키지는 설치 유지)
- Kafka: in-cluster 신규 추가
- Alert Module: in-cluster 신규 추가
- secloudit-util VM 신규: ChartMuseum, CoreDNS, DNS Agent
- Console VM 컴포넌트 추가: gateway, jxgo, k8s-go, java-api

### 배포 구조
[VM 배포 — docker-compose]
innogrid-auth VM   : Keycloak (8012), MySQL for Keycloak (3306)
Console VM         : portal (8010), admin-portal (8011), gateway, jxgo,
k8s-go, java-api, MySQL, gitlab-runner
Logging VM         : MongoDB (27017), FluentD Forwarder (24224)
Util VM            : ChartMuseum (5080), CoreDNS, DNS Agent
[in-cluster 배포 — kubectl apply (k8s-master에서 실행)]
Calico, Nginx Ingress, Prometheus, Tekton(패키지만 유지)
Istio, FluentD Agent DaemonSet, NFS Provisioner
Metrics Server, Kafka (신규), Alert Module (신규)

> DevOpsit (GitLab, Harbor, ArgoCD)은 별도 관리 — 우리 자동화 범위 아님

### 레포지토리 구조
secloudit-v2.3/
├── inventories/
│   ├── demo/hosts.yaml      ← innogrid-auth, console-vm, logging-vm, util-vm, k8s-master
│   └── qa/hosts.yaml
├── group_vars/
│   └── all.yaml             ← 공통 변수
├── roles/
│   ├── innogrid-auth/       ← Keycloak + MySQL (docker-compose)
│   ├── secloudit-console/   ← Console VM 컴포넌트 (docker-compose)
│   ├── secloudit-logging/   ← MongoDB + FluentD Forward (docker-compose)
│   ├── secloudit-util/      ← ChartMuseum + CoreDNS + DNS Agent (docker-compose)
│   ├── fluentd-agent/       ← in-cluster FluentD DaemonSet
│   ├── tekton/              ← in-cluster Tekton (패키지만 설치)
│   ├── kafka/               ← in-cluster Kafka (신규)
│   └── alert-module/        ← in-cluster Alert Module (신규)
└── playbooks/
└── deploy-secloudit.yaml

### 설치 순서 (변경 금지)

innogrid-auth VM — Keycloak + MySQL
Console VM       — gateway → jxgo → java-api → k8s-go → portal → admin-portal
→ MySQL → gitlab-runner
Logging VM       — MongoDB → FluentD Forwarder
Util VM          — ChartMuseum → CoreDNS → DNS Agent
in-cluster       — FluentD Agent DaemonSet
in-cluster       — Tekton (패키지 설치)
in-cluster       — Kafka
in-cluster       — Alert Module


### 코딩 규칙
- Ansible: 모든 태스크에 name: 필수
- 멱등성 필수 — docker ps로 컨테이너 존재 여부 확인 후 skip
- 시크릿: 절대 평문 금지, vault_ prefix 변수로만 참조
- docker-compose.yaml은 templates/ 에서 Jinja2(.j2)로 관리
- in-cluster 태스크: kubectl apply 전 kubeconfig 경로 확인 필수

### 시크릿 항목 (값 기재 금지)
- vault_keycloak_admin_password
- vault_keycloak_db_password
- vault_mysql_root_password
- vault_mongodb_root_password
- vault_secloudit_admin_password
- vault_chartmuseum_password

### 미확인 항목 (# TODO — 임의 결정 금지)
- 각 VM 실제 IP 주소
- k8s-master IP (k8s-cluster Terraform output)
- Keycloak realm/client 초기 설정값
- Kafka 세부 버전 및 설정
- Alert Module 세부 버전 및 설정
- CoreDNS / DNS Agent 설정값
- FluentD FLUENT_FORWARD_HOST, CLUSTER_DIVIDE_VALUE

---

## 3단계 — research.md 채우기

아래 8개 섹션으로 작성해라:

1. 자동화 대상
   - VM 4종 배포 (innogrid-auth, console, logging, util)
   - in-cluster OSS 배포
   - DevOpsit은 우리 범위 아님 명시

2. 기술 스택 및 버전
   - Ansible, Docker, docker-compose, Rocky Linux 9.1
   - OSS 버전표 (확인된 것만, 미확인은 # TODO)

3. 아키텍처
   - VM 4종 구성 + in-cluster 구성 + 포트 구성

4. 핵심 변수/설정값
   - 레지스트리, 포트, K8s 버전

5. 의존성 및 순서
   - 8단계 설치 순서

6. 시크릿 항목 (값 기재 금지)
   - vault_ 변수 6개

7. 변경 영향 범위
   - v2.0 대비 변경사항
   - DevOpsit 이관 항목 명시

8. 미확인 항목

---

## 완료 기준

- [ ] projects/secloudit-v2.3/ 디렉토리 구조 생성
- [ ] .ai/CLAUDE.md 섹션 2 내용 채워짐 (섹션 1 변경 없음)
- [ ] .ai/research.md 8개 섹션 작성 완료
- [ ] git log에 초기 커밋 확인

완료 후 두 파일 주요 내용을 요약해서 보고하고 git commit 해라.
