# research.md — secloudit-v2.3

> 작성일: 2026-03-16
> 상태: `완료`
> 목적: SECloudit v2.3 배포 자동화를 위한 기술 분석 및 구현 범위 정의

---

## 1. 자동화 대상

### 무엇을 만드는가
- **VM 4종 배포 (docker-compose 기반)**
  - innogrid-auth VM: Keycloak + MySQL for Keycloak
  - Console VM: portal, admin-portal, gateway, jxgo, k8s-go, java-api, MySQL, gitlab-runner
  - Logging VM: MongoDB + FluentD Forwarder
  - Util VM: ChartMuseum + CoreDNS + DNS Agent

- **in-cluster OSS 배포 (kubectl apply 기반)**
  - FluentD Agent DaemonSet
  - Tekton (패키지만 설치)
  - Kafka (신규)
  - Alert Module (신규)

### 범위 외 (DevOpsit 관리)
> GitLab, Harbor, ArgoCD는 DevOpsit 팀이 별도 관리 — 우리 자동화 범위 아님

---

## 2. 기술 스택 및 버전

| 항목 | 버전 | 비고 |
|---|---|---|
| OS | Rocky Linux 9.1 | 모든 VM 공통 |
| Ansible | 최신 안정 버전 | 자동화 도구 |
| Docker | 최신 안정 버전 | 컨테이너 런타임 |
| docker-compose | 최신 안정 버전 | VM 배포 |
| Keycloak | # TODO | innogrid-auth VM |
| MySQL | # TODO | Keycloak용, Console용 |
| MongoDB | # TODO | Logging VM |
| FluentD | # TODO | Forwarder + Agent |
| ChartMuseum | # TODO | Util VM |
| CoreDNS | # TODO | Util VM |
| Kafka | # TODO | in-cluster (신규) |
| Alert Module | # TODO | in-cluster (신규) |
| Tekton | # TODO | in-cluster (패키지만) |

---

## 3. 아키텍처

### 전체 구조
```
┌─────────────────────────────────────────────────────────────────────┐
│                          VM 배포 (docker-compose)                    │
├─────────────────┬─────────────────┬─────────────────┬───────────────┤
│ innogrid-auth   │ Console VM      │ Logging VM      │ Util VM       │
│ ─────────────   │ ──────────      │ ──────────      │ ───────       │
│ Keycloak :8012  │ portal :8010    │ MongoDB :27017  │ ChartMuseum   │
│ MySQL :3306     │ admin :8011     │ FluentD :24224  │   :5080       │
│                 │ gateway         │                 │ CoreDNS       │
│                 │ jxgo            │                 │ DNS Agent     │
│                 │ k8s-go          │                 │               │
│                 │ java-api        │                 │               │
│                 │ MySQL           │                 │               │
│                 │ gitlab-runner   │                 │               │
└─────────────────┴─────────────────┴─────────────────┴───────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                    in-cluster 배포 (kubectl apply)                   │
│                         k8s-master에서 실행                          │
├─────────────────────────────────────────────────────────────────────┤
│ [기존 유지]                                                          │
│   Calico, Nginx Ingress, Prometheus, Istio, NFS Provisioner,        │
│   Metrics Server, Tekton (패키지만)                                  │
│                                                                      │
│ [신규 추가]                                                          │
│   FluentD Agent DaemonSet, Kafka, Alert Module                      │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                    DevOpsit 관리 (범위 외)                           │
├─────────────────────────────────────────────────────────────────────┤
│   GitLab, Harbor, ArgoCD                                            │
└─────────────────────────────────────────────────────────────────────┘
```

### 포트 구성

| VM/서비스 | 포트 | 용도 |
|---|---|---|
| Keycloak | 8012 | 인증 서비스 |
| MySQL (Keycloak) | 3306 | Keycloak DB |
| portal | 8010 | 사용자 포털 |
| admin-portal | 8011 | 관리자 포털 |
| MongoDB | 27017 | 로그 저장소 |
| FluentD Forwarder | 24224 | 로그 수집 |
| ChartMuseum | 5080 | Helm 차트 저장소 |

### Ansible Roles 구조
```
roles/
├── innogrid-auth/       ← Keycloak + MySQL (docker-compose)
├── secloudit-console/   ← Console VM 컴포넌트 (docker-compose)
├── secloudit-logging/   ← MongoDB + FluentD Forward (docker-compose)
├── secloudit-util/      ← ChartMuseum + CoreDNS + DNS Agent (docker-compose)
├── fluentd-agent/       ← in-cluster FluentD DaemonSet
├── tekton/              ← in-cluster Tekton (패키지만 설치)
├── kafka/               ← in-cluster Kafka (신규)
└── alert-module/        ← in-cluster Alert Module (신규)
```

---

## 4. 핵심 변수/설정값

### 공통 변수 (group_vars/all.yaml)
```yaml
# 이미지 레지스트리
image_registry: sample.harbor.com

# K8s 설정
# TODO: kubeconfig_path, k8s_master_ip 확인 필요

# 포트 설정 (확정)
keycloak_port: 8012
portal_port: 8010
admin_portal_port: 8011
mongodb_port: 27017
fluentd_port: 24224
chartmuseum_port: 5080
mysql_port: 3306
```

### 환경별 인벤토리 (inventories/)
```yaml
# demo/hosts.yaml, qa/hosts.yaml
all:
  children:
    innogrid_auth:
      hosts:
        innogrid-auth-vm:
          ansible_host: # TODO: 실제 IP
    console_vm:
      hosts:
        console-vm:
          ansible_host: # TODO: 실제 IP
    logging_vm:
      hosts:
        logging-vm:
          ansible_host: # TODO: 실제 IP
    util_vm:
      hosts:
        util-vm:
          ansible_host: # TODO: 실제 IP
    k8s_master:
      hosts:
        k8s-master:
          ansible_host: # TODO: Terraform output
```

---

## 5. 의존성 및 순서

### 설치 순서 (8단계, 변경 금지)

| 단계 | 대상 | 컴포넌트 | 선행 조건 |
|---|---|---|---|
| 1 | innogrid-auth VM | Keycloak + MySQL | Docker 설치됨 |
| 2 | Console VM | gateway → jxgo → java-api → k8s-go → portal → admin-portal → MySQL → gitlab-runner | Keycloak 기동 완료 |
| 3 | Logging VM | MongoDB → FluentD Forwarder | Docker 설치됨 |
| 4 | Util VM | ChartMuseum → CoreDNS → DNS Agent | Docker 설치됨 |
| 5 | in-cluster | FluentD Agent DaemonSet | K8s 클러스터 준비됨 |
| 6 | in-cluster | Tekton (패키지 설치) | K8s 클러스터 준비됨 |
| 7 | in-cluster | Kafka | K8s 클러스터 준비됨 |
| 8 | in-cluster | Alert Module | Kafka 기동 완료 |

### 전역 선행 조건
- k8s-cluster 프로젝트 완료 (K8s 클러스터 구축 완료)
- 각 VM에 Docker 설치됨
- 이미지 레지스트리(sample.harbor.com) 접근 가능

---

## 6. 시크릿 항목 (값 기재 금지)

> ⚠️ **값 기재 금지** — vault_ prefix 변수로만 참조

| 항목 | 용도 | 사용처 |
|---|---|---|
| `vault_keycloak_admin_password` | Keycloak 관리자 비밀번호 | innogrid-auth |
| `vault_keycloak_db_password` | Keycloak용 MySQL 비밀번호 | innogrid-auth |
| `vault_mysql_root_password` | MySQL root 비밀번호 | Console VM |
| `vault_mongodb_root_password` | MongoDB root 비밀번호 | Logging VM |
| `vault_secloudit_admin_password` | SECloudit 관리자 비밀번호 | Console VM |
| `vault_chartmuseum_password` | ChartMuseum 인증 비밀번호 | Util VM |

---

## 7. 변경 영향 범위

### v2.0 대비 변경사항

| 구분 | 변경 내용 | 영향 |
|---|---|---|
| 신규 추가 | innogrid-auth VM (Keycloak + MySQL) | 인증 체계 변경 |
| 신규 추가 | Util VM (ChartMuseum, CoreDNS, DNS Agent) | 유틸리티 서비스 분리 |
| 신규 추가 | Kafka (in-cluster) | 메시지 큐 도입 |
| 신규 추가 | Alert Module (in-cluster) | 알림 기능 추가 |
| 컴포넌트 추가 | Console VM: gateway, jxgo, k8s-go, java-api | API 레이어 확장 |
| 범위 제외 | GitLab, Harbor, ArgoCD | DevOpsit 이관 |
| 기능 변경 | Tekton | 메뉴에서 제거 (패키지만 설치 유지) |

### DevOpsit 이관 항목 (우리 범위 외)
- GitLab: 소스 코드 저장소
- Harbor: 컨테이너 이미지 레지스트리
- ArgoCD: GitOps 배포 도구

### 영향받는 기존 컴포넌트
- Console VM: 기존 portal, admin-portal에 새 컴포넌트(gateway, jxgo 등) 추가
- Logging VM: 변경 없음 (MongoDB + FluentD Forwarder 유지)

---

## 8. 미확인 항목

| 항목 | 영향 범위 | 확인 방법 |
|---|---|---|
| 각 VM 실제 IP 주소 | 인벤토리 작성 | 인프라팀 확인 |
| k8s-master IP | in-cluster 배포 | k8s-cluster Terraform output |
| Keycloak realm/client 초기 설정값 | 인증 연동 | 보안팀/개발팀 확인 |
| Kafka 세부 버전 및 설정 | in-cluster Kafka 배포 | 개발팀 확인 |
| Alert Module 세부 버전 및 설정 | in-cluster Alert 배포 | 개발팀 확인 |
| CoreDNS / DNS Agent 설정값 | DNS 서비스 구성 | 인프라팀 확인 |
| FluentD FLUENT_FORWARD_HOST | 로그 수집 대상 | 개발팀 확인 |
| FluentD CLUSTER_DIVIDE_VALUE | 클러스터 구분 | 개발팀 확인 |

---

## 메모

- 모든 docker-compose.yaml은 templates/ 디렉토리에서 Jinja2(.j2)로 관리
- 멱등성 필수: docker ps로 컨테이너 존재 여부 확인 후 skip
- 시크릿은 절대 평문 금지, vault_ prefix 변수로만 참조
- in-cluster 태스크 실행 전 kubeconfig 경로 확인 필수
