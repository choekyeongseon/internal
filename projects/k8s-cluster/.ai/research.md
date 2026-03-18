# research.md — k8s-cluster

> 작성일: 2026-03-16
> 상태: `진행 중`
> 목적: SECloudit PaaS 플랫폼용 K8s 클러스터 자동 구축 자동화 분석

---

## 1. 자동화/구현 대상

### 무엇을 만드는가
- K8s 클러스터 구축 자동화 (VM 프로비저닝 + OS 설정 + K8s 설치 + OSS 배포)
- Terraform으로 OpenStack VM 프로비저닝
- Ansible로 OS 설정, CRI-O 설치, kubeadm 클러스터 초기화
- K8s OSS 컴포넌트 자동 배포 (Calico, Ingress, ArgoCD 등)

### 핵심 제약 조건
- 고객 환경 전부 폐쇄망 — 인터넷 없이 RPM/이미지 번들로만 설치
- SECloudit 버전별로 K8s 버전이 다름 — secloudit_version 변수로 분기 필수
- 멱등성 보장 — 재실행 시에도 안전하게 동작해야 함
- kubeadm 토큰 TTL 24시간 제약 — idempotency 처리 필수

---

## 2. 기술 스택 및 버전

| 항목 | 버전 | 비고 |
|---|---|---|
| IaC | Terraform (OpenStack Provider) | VM 프로비저닝 |
| 구성관리 | Ansible | OS 설정, K8s 설치 |
| 컨테이너 런타임 | CRI-O 1.23~1.27 | K8s 버전에 맞춰 분기 |
| K8s 설치 | kubeadm | 클러스터 초기화/조인 |
| OS | Rocky Linux 9.x | 폐쇄망 RPM 설치 |
| LB | HAProxy | API Server 앞단 |

---

## 3. 아키텍처 / 구성 파악

### 전체 구조
```
                    ┌─────────────┐
                    │   HAProxy   │ (LB)
                    │  :6443/:26443│
                    └──────┬──────┘
                           │
                    ┌──────┴──────┐
                    │   Master    │ (Single Master)
                    │   (etcd)    │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
   ┌─────┴─────┐     ┌─────┴─────┐     ┌─────┴─────┐
   │  Worker1  │     │  Worker2  │     │  Worker3  │
   └───────────┘     └───────────┘     └───────────┘
         │
   ┌─────┴─────┐
   │    NFS    │ (Persistent Storage)
   └───────────┘
```

### 주요 모듈 역할
- `vm-provision/modules/k8s-cluster`: OpenStack VM 프로비저닝 (Master×1, Worker×N, HAProxy, NFS)
- `k8s-deploy/roles/common`: hostname, /etc/hosts, Harbor CA trust 등록
- `k8s-deploy/roles/k8s-preinstall`: SELinux, swap off, 커널 모듈, sysctl, firewalld
- `k8s-deploy/roles/k8s-install`: CRI-O, kubelet/kubeadm/kubectl RPM 설치
- `k8s-deploy/roles/k8s-init`: kubeadm init (Master) / join (Worker)
- `k8s-deploy/roles/k8s-oss`: Calico, Ingress, NFS Provisioner, Metrics Server, Prometheus, ArgoCD, Tekton, Istio, Kafka

### 의존성 관계
- `common` → `k8s-preinstall`: 기본 호스트 설정 후 K8s 사전 설정
- `k8s-preinstall` → `k8s-install`: OS 준비 후 K8s 컴포넌트 설치
- `k8s-install` → `k8s-init`: RPM 설치 후 클러스터 초기화
- `k8s-init` → `k8s-oss`: 클러스터 준비 후 OSS 배포

---

## 4. 핵심 변수 / 설정값

```yaml
# 분기 기준 변수
secloudit_version: v1.5 / v2.0 / v2.3 / v2.6
cluster_type: all-in-one / separated
environment: demo / qa

# K8s 버전 매핑 (group_vars/all.yaml)
k8s_version_map:
  v1.5: "1.23.17"
  v2.0: "1.27.8"
  # v2.3, v2.6: TODO 확인 필요

# CRI-O 버전 (K8s major.minor와 동일)
crio_version: "{{ k8s_version | regex_replace('^(\\d+\\.\\d+).*', '\\1') }}"

# HAProxy 포트 분기
haproxy_api_frontend_port: "{{ '26443' if secloudit_version == 'v1.5' else '6443' }}"
haproxy_http_nodeport: "{{ '30180' if secloudit_version == 'v1.5' else '30080' }}"
haproxy_https_nodeport: "{{ '30181' if secloudit_version == 'v1.5' else '30443' }}"
```

### 주요 환경 변수
- `KUBECONFIG`: 클러스터 접근 설정 파일 경로
- `HARBOR_ADMIN_PASSWORD`: Harbor 레지스트리 관리자 비밀번호 (vault 참조)

---

## 5. 의존성 및 순서

### 실행 순서
1. **vm-provision (Terraform)**: OpenStack VM 프로비저닝 (HAProxy, Master×1, Worker×N, NFS)
2. **k8s-deploy/common**: 호스트명, /etc/hosts, Harbor CA trust
3. **k8s-deploy/k8s-preinstall**: SELinux, swap, 커널 모듈, sysctl, firewalld
4. **k8s-deploy/k8s-install**: CRI-O, kubelet/kubeadm/kubectl RPM 설치
5. **k8s-deploy/k8s-init (Master)**: kubeadm init
6. **k8s-deploy/k8s-oss (Calico)**: CNI 설치 (Worker join 전 필수!)
7. **k8s-deploy/k8s-init (Worker)**: kubeadm join
8. **k8s-deploy/k8s-oss (나머지)**: Ingress → NFS → Metrics → Prometheus → ArgoCD → Tekton → Istio → Kafka

### 선행 조건
- OpenStack 환경 접근 가능 (credentials)
- Harbor 레지스트리에 필요한 이미지 push 완료
- RPM 번들 준비 (오프라인 설치용)

### 후행 작업
- kubeconfig 파일 추출 및 전달
- secloudit-v{버전} 프로젝트에서 애플리케이션 배포

---

## 6. 시크릿 / 접속 정보 항목 목록

> ⚠️ **값 기재 금지** — 항목명만 나열

| 항목 | 용도 | 저장 위치 |
|---|---|---|
| `vault_harbor_admin_password` | Harbor 레지스트리 접근 | Ansible Vault |
| `kubeconfig` | K8s 클러스터 접근 | 생성 후 추출 |
| `openstack_credentials` | OpenStack API 접근 | 환경변수 또는 clouds.yaml |
| `kubeadm_token` | Worker 노드 join | kubeadm init 시 생성 |
| `kubeadm_ca_cert_hash` | Worker 노드 join 검증 | kubeadm init 시 생성 |

---

## 7. 변경 영향 범위

### 사이드이펙트 체크 항목
- [ ] 기존 클러스터에 영향 없음 (신규 구축만)
- [ ] SECloudit 버전별 분기 정확성 검증
- [ ] 폐쇄망 환경에서 RPM/이미지 누락 없음 확인
- [ ] kubeadm 토큰 만료 시 재생성 로직 동작 확인

### 영향받는 컴포넌트
- 이 프로젝트 완료 후 `secloudit-v{버전}` 프로젝트가 구축된 클러스터 위에 배포

### 테스트 필요 영역
- Demo 환경에서 전체 플로우 테스트
- 각 SECloudit 버전별 K8s 버전 조합 테스트
- 멱등성 테스트 (2회 연속 실행)

---

## 8. 미확인 항목

| 항목 | 영향 범위 | 확인 방법 |
|---|---|---|
| v2.0 / v2.3 현장 K8s 버전 | RPM 버전, CRI-O 버전 | 현장 환경 확인 |
| v2.6 K8s 버전 | 전체 버전 분기 로직 | 요구사항 확인 |
| demo / qa 클러스터 노드 수 및 사양 | Terraform 변수 | OpenStack flavor 목록 확인 |
| OpenStack 네트워크/이미지 이름 | Terraform 설정 | 환경별 확인 |
| QA 클러스터 수명 관리 방식 | Terraform workspace 운영 | TTL vs 수동 destroy 결정 |
| Jira 티켓 필드 정의 | QA workspace 네이밍 자동화 | 버전/패턴 선택 필드명 확인 |

---

## 메모

- Calico는 반드시 Master init 직후, Worker join 이전에 설치해야 함
- Metrics Server는 --kubelet-insecure-tls + hostNetwork: true 패치 필수
- ArgoCD HA 모드는 워커 3대 미만 시 podAntiAffinity 제거 패치 필요
- Harbor 인증서: 모든 노드에 CA trust 등록 필요 (update-ca-trust)
