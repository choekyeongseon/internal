아래 순서대로 진행해라.
아직 구현하지 마라. 각 단계 완료 후 결과를 보고하고 다음 단계로 넘어가라.

---

## 1단계 — 프로젝트 초기화

프레임워크 루트에서 실행(이미 완료함):

완료 후 생성된 구조를 보고해라.

---

## 2단계 — CLAUDE.md 섹션 2 채우기

projects/secloudit-v2.0/.ai/CLAUDE.md 의 섹션 2를 아래 내용으로 채워라.
섹션 1은 절대 수정하지 마라.

### 프로젝트 개요
- 프로젝트명: secloudit-v2.0
- 목적: SECloudit v2.0 솔루션 컴포넌트를 각 VM에 docker-compose로 배포하고,
  K8s 클러스터 안에 OSS를 kubectl apply로 배포
- 기술스택: Ansible, Docker, docker-compose
- 선행 조건: k8s-cluster 프로젝트 완료 (K8s 클러스터 구축 완료)
- 이미지 레지스트리: sample.harbor.com (모든 프로젝트 공통)

### v1.5 대비 핵심 변경사항
- 컨테이너 런타임: podman-compose → docker-compose
- HAProxy API 포트: 26443 → 6443
- K8s 버전: 1.23.x 고정 → 1.24~1.27 선택 (secloudit_version 변수로 분기)
- Calico 버전 확정: 3.26.3
- 추가 VM 컴포넌트: Harbor, GitLab CE, ChartMuseum, gitlabci-module
- 추가 in-cluster OSS: ArgoCD, Istio

### 배포 구조
[VM 배포 — docker-compose]
Console VM  : secloudit-console (9080), MySQL (3306), MongoDB (27017),
FluentD Forward (24224), GitLab (8080/8443/8022),
ChartMuseum (5080), gitlabci-module (8093/9091)
LB VM       : HAProxy (6443 → K8s API, 80/443 → Ingress)
[in-cluster 배포 — kubectl apply (k8s-master에서 실행)]
Calico 3.26.3, Nginx Ingress (NodePort 30080/30443)
Prometheus, ArgoCD, Tekton Pipelines + Triggers
Istio, FluentD Agent DaemonSet
NFS Provisioner, Metrics Server

> VM 구성은 현장별로 1대/2대/3대 통합 가능.
> 우리 환경: secloudit-v1.5와 동일하게 Console VM + k8s-master로 운영.

### 레포지토리 구조
secloudit-v2.0/
├── inventories/
│   ├── demo/hosts.yaml       ← console-vm, k8s-master
│   └── qa/hosts.yaml
├── group_vars/
│   └── all.yaml              ← 공통 변수 (버전, 포트, 시크릿 참조)
├── roles/
│   ├── secloudit-console/    ← 전체 console VM 컴포넌트 (docker-compose)
│   ├── fluentd-agent/        ← in-cluster FluentD DaemonSet
│   ├── argocd/               ← in-cluster ArgoCD
│   ├── tekton/               ← in-cluster Tekton
│   └── istio/                ← in-cluster Istio
└── playbooks/
└── deploy-secloudit.yaml

### 설치 순서 (변경 금지)

Console VM  — docker-compose 전체 컴포넌트 구동
(MySQL → MongoDB → FluentD → GitLab → ChartMuseum
→ gitlabci-module → secloudit-console 순서)
in-cluster  — FluentD Agent DaemonSet
in-cluster  — ArgoCD
in-cluster  — Tekton Pipelines + Triggers
in-cluster  — Istio


### 코딩 규칙
- Ansible: 모든 태스크에 name: 필수
- 멱등성 필수 — docker ps로 컨테이너 존재 여부 확인 후 skip
- 시크릿: 절대 평문 금지, vault_ prefix 변수로만 참조
- docker-compose.yaml은 templates/ 에서 Jinja2(.j2)로 관리
- in-cluster 태스크: kubectl apply 전 kubeconfig 경로 확인 필수
- K8s 버전 분기: group_vars/all.yaml의 k8s_version_map 사용

### 시크릿 항목 (값 기재 금지)
- vault_mysql_root_password
- vault_mongodb_root_password
- vault_harbor_admin_password
- vault_gitlab_root_password
- vault_chartmuseum_password
- vault_argocd_admin_password
- vault_secloudit_admin_password

### OSS 버전 (v2.0 기준)

| 컴포넌트 | 버전 |
|---|---|
| K8s | 1.24.14 / 1.25.10 / 1.26.11 / 1.27.8 (선택) |
| Calico | 3.26.3 |
| GitLab CE | 15.11.3-ce.0 |
| GitLab Runner | v15.11.1 |
| ChartMuseum | v0.16.0 |
| MongoDB | 5.0 |
| MySQL | 8.0 |
| Tekton Pipeline | 0.44.0 |
| Tekton Triggers | 0.22.0 |

### 미확인 항목 (# TODO — 임의 결정 금지)
- Console VM 실제 IP
- k8s-master IP (k8s-cluster Terraform output)
- FluentD FLUENT_FORWARD_HOST, CLUSTER_DIVIDE_VALUE
- Nginx Ingress / Prometheus / ArgoCD / Istio 세부 버전
- gitlabci-module 상세 설정값 (JWT secret 등)

---

## 3단계 — research.md 채우기

아래 8개 섹션으로 작성해라:

1. 자동화 대상
2. 기술 스택 및 버전 (OSS 버전표 포함)
3. 아키텍처 (VM 구성 + in-cluster 구성 + 포트 구성)
4. 핵심 변수/설정값 (K8s 버전 분기, 포트, 레지스트리)
5. 의존성 및 순서 (5단계 설치 순서)
6. 시크릿 항목 (값 기재 금지)
7. 변경 영향 범위 (k8s-cluster 선행, v1.5 대비 차이)
8. 미확인 항목

---

## 완료 기준

- [ ] projects/secloudit-v2.0/ 디렉토리 구조 생성
- [ ] .ai/CLAUDE.md 섹션 2 내용 채워짐 (섹션 1 변경 없음)
- [ ] .ai/research.md 8개 섹션 작성 완료
- [ ] git log에 초기 커밋 확인

완료 후 두 파일 주요 내용을 요약해서 보고하고 git commit 해라.
