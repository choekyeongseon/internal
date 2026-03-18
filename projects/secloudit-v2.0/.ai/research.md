# research.md — secloudit-v2.0

> 작성일: 2026-03-16
> 상태: `완료`
> 목적: SECloudit v2.0 배포 자동화를 위한 기술 분석

---

## 1. 자동화 대상

### 무엇을 만드는가
- SECloudit v2.0 솔루션 컴포넌트를 각 VM에 docker-compose로 배포
- K8s 클러스터 안에 OSS를 kubectl apply로 배포
- Ansible 기반 배포 자동화 플레이북

### 핵심 제약 조건
- 선행 조건: k8s-cluster 프로젝트 완료 (K8s 클러스터 구축 완료)
- 이미지 레지스트리: sample.harbor.com 사용 (모든 프로젝트 공통)
- 컨테이너 런타임: Docker + docker-compose (v1.5의 podman-compose에서 변경)
- 설치 순서 변경 금지 (의존성 관계 준수)

---

## 2. 기술 스택 및 버전

### 인프라 도구

| 항목 | 버전 | 비고 |
|---|---|---|
| Ansible | 2.9+ | 배포 자동화 |
| Docker | 20.10+ | 컨테이너 런타임 |
| docker-compose | 2.x | VM 컴포넌트 오케스트레이션 |
| kubectl | 1.24+ | in-cluster 배포 |

### OSS 버전 (v2.0 기준)

| 컴포넌트 | 버전 | 비고 |
|---|---|---|
| Kubernetes | 1.24.14 / 1.25.10 / 1.26.11 / 1.27.8 | 선택 가능 |
| Calico | 3.26.3 | CNI |
| GitLab CE | 15.11.3-ce.0 | |
| GitLab Runner | v15.11.1 | |
| ChartMuseum | v0.16.0 | Helm Chart 저장소 |
| MongoDB | 5.0 | |
| MySQL | 8.0 | |
| Tekton Pipeline | 0.44.0 | v1.5: 0.28.3 |
| Tekton Triggers | 0.22.0 | v1.5: 0.18.0 |

---

## 3. 아키텍처

### VM 구성

```
[Console VM — docker-compose]
├── MySQL (3306)
├── MongoDB (27017)
├── FluentD Forward (24224)
├── GitLab CE (8080/8443/8022)
├── ChartMuseum (5080)
├── gitlabci-module (8093/9091)
└── secloudit-console (9080)

[LB VM — docker-compose] (선택)
└── HAProxy (6443 → K8s API, 80/443 → Ingress)
```

> 우리 환경: Console VM + k8s-master로 운영 (LB VM 미사용)

### in-cluster 구성

```
[k8s-master에서 kubectl apply]
├── Calico 3.26.3 (CNI)
├── Nginx Ingress (NodePort 30080/30443)
├── Prometheus
├── ArgoCD
├── Tekton Pipelines + Triggers
├── Istio
├── FluentD Agent DaemonSet
├── NFS Provisioner
└── Metrics Server
```

### 포트 구성

| 서비스 | 포트 | 위치 |
|---|---|---|
| MySQL | 3306 | Console VM |
| MongoDB | 27017 | Console VM |
| FluentD Forward | 24224 | Console VM |
| GitLab HTTP | 8080 | Console VM |
| GitLab HTTPS | 8443 | Console VM |
| GitLab SSH | 8022 | Console VM |
| ChartMuseum | 5080 | Console VM |
| gitlabci-module API | 8093 | Console VM |
| gitlabci-module Metrics | 9091 | Console VM |
| secloudit-console | 9080 | Console VM |
| HAProxy K8s API | 6443 | LB VM |
| HAProxy Ingress HTTP | 80 | LB VM |
| HAProxy Ingress HTTPS | 443 | LB VM |
| Nginx Ingress HTTP | 30080 | K8s NodePort |
| Nginx Ingress HTTPS | 30443 | K8s NodePort |

---

## 4. 핵심 변수 / 설정값

### K8s 버전 분기

```yaml
# group_vars/all.yaml
k8s_version_map:
  "1.24": "1.24.14"
  "1.25": "1.25.10"
  "1.26": "1.26.11"
  "1.27": "1.27.8"

# 선택된 버전
k8s_version: "1.27"  # 또는 secloudit_version 변수로 분기
```

### 레지스트리 설정

```yaml
registry_host: "sample.harbor.com"
registry_port: 443
```

### 포트 설정

```yaml
# Console VM 컴포넌트
mysql_port: 3306
mongodb_port: 27017
fluentd_forward_port: 24224
gitlab_http_port: 8080
gitlab_https_port: 8443
gitlab_ssh_port: 8022
chartmuseum_port: 5080
gitlabci_api_port: 8093
gitlabci_metrics_port: 9091
console_port: 9080

# HAProxy (LB VM)
haproxy_api_port: 6443  # v1.5: 26443 → v2.0: 6443

# Nginx Ingress (in-cluster)
ingress_http_nodeport: 30080
ingress_https_nodeport: 30443
```

### kubeconfig 경로

```yaml
kubeconfig_path: "/etc/kubernetes/admin.conf"
```

---

## 5. 의존성 및 순서

### 설치 순서 (5단계)

```
1. Console VM  — docker-compose 전체 컴포넌트 구동
   MySQL → MongoDB → FluentD → GitLab → ChartMuseum
   → gitlabci-module → secloudit-console

2. in-cluster  — FluentD Agent DaemonSet

3. in-cluster  — ArgoCD

4. in-cluster  — Tekton Pipelines + Triggers

5. in-cluster  — Istio
```

### 선행 조건
- k8s-cluster 프로젝트 완료 (K8s 클러스터 구축)
- Harbor 이미지 로드 완료 (sample.harbor.com)
- kubeconfig 접근 가능

### 의존성 관계

```
MySQL ← secloudit-console (DB 연결)
MongoDB ← secloudit-console (로그 저장)
FluentD Forward ← FluentD Agent (로그 전달)
GitLab ← gitlabci-module (Git 연동)
ChartMuseum ← ArgoCD (Helm Chart 참조)
```

---

## 6. 시크릿 항목

> ⚠️ **값 기재 금지** — 항목명만 나열

| 항목 | 용도 | 저장 위치 |
|---|---|---|
| `vault_mysql_root_password` | MySQL root 접속 | Ansible Vault |
| `vault_mongodb_root_password` | MongoDB root 접속 | Ansible Vault |
| `vault_harbor_admin_password` | Harbor 관리자 | Ansible Vault |
| `vault_gitlab_root_password` | GitLab root 접속 | Ansible Vault |
| `vault_chartmuseum_password` | ChartMuseum 인증 | Ansible Vault |
| `vault_argocd_admin_password` | ArgoCD 관리자 | Ansible Vault |
| `vault_secloudit_admin_password` | SECloudit 관리자 | Ansible Vault |

---

## 7. 변경 영향 범위

### v1.5 대비 주요 변경사항

| 항목 | v1.5 | v2.0 |
|---|---|---|
| 컨테이너 런타임 | podman-compose | docker-compose |
| HAProxy API 포트 | 26443 | 6443 |
| K8s 버전 | 1.23.x 고정 | 1.24~1.27 선택 |
| Calico 버전 | 미확정 | 3.26.3 |
| Tekton Pipeline | 0.28.3 | 0.44.0 |
| Tekton Triggers | 0.18.0 | 0.22.0 |
| 추가 VM 컴포넌트 | - | GitLab, ChartMuseum, gitlabci-module |
| 추가 in-cluster | - | ArgoCD, Istio |

### 선행 프로젝트 의존성
- k8s-cluster: K8s 클러스터 구축
- Terraform output: k8s_master_ip

### 영향받는 컴포넌트
- 기존 v1.5 role 재사용 가능: fluentd-agent, tekton (버전 업그레이드 필요)
- 신규 role 필요: secloudit-console (통합), argocd, istio

---

## 8. 미확인 항목

| 항목 | 영향 범위 | 확인 방법 |
|---|---|---|
| Console VM 실제 IP | inventories 작성 | 인프라팀 확인 |
| k8s-master IP | inventories 작성 | Terraform output |
| FluentD FLUENT_FORWARD_HOST | FluentD Agent 설정 | Console VM IP 사용 |
| FluentD CLUSTER_DIVIDE_VALUE | 클러스터 구분 | 환경별 값 확인 |
| Nginx Ingress 버전 | in-cluster 배포 | 공식 문서 확인 |
| Prometheus 버전 | in-cluster 배포 | 공식 문서 확인 |
| ArgoCD 버전 | in-cluster 배포 | 공식 문서 확인 |
| Istio 버전 | in-cluster 배포 | 공식 문서 확인 |
| gitlabci-module JWT secret | gitlabci-module 설정 | 설계 문서 확인 |

---

## 메모

- v2.0은 v1.5 대비 VM 컴포넌트가 Console VM 1대로 통합됨
- LB VM은 현장별 선택 사항 (우리 환경에서는 미사용)
- in-cluster OSS가 대폭 추가됨 (ArgoCD, Istio 등)
- K8s 버전 분기 로직 구현 필요 (k8s_version_map)
