# k8s-deploy

Ansible로 K8s 클러스터를 구축하는 플레이북 및 Role.

## 구조

```
k8s-deploy/
├── inventories/
│   ├── demo/hosts.yaml       # Demo 환경 인벤토리
│   └── qa/hosts.yaml         # QA 환경 인벤토리
├── group_vars/
│   ├── all.yaml              # 전역 변수 (버전 매핑)
│   ├── masters.yaml          # Master 노드 변수
│   └── haproxy.yaml          # HAProxy 변수
├── roles/
│   ├── common/               # 공통 설정 (hostname, hosts, CA trust)
│   ├── k8s-preinstall/       # K8s 사전 설정 (SELinux, swap, sysctl)
│   ├── k8s-install/          # K8s 컴포넌트 설치 (CRI-O, kubeadm)
│   ├── k8s-init/             # kubeadm init/join
│   └── k8s-oss/              # OSS 컴포넌트 (Calico, ArgoCD 등)
├── playbooks/
│   └── build-cluster.yaml    # 메인 플레이북
├── templates/
│   └── kubeadm-config.yaml.j2
└── README.md
```

## 사전 요구사항

- Ansible >= 2.9
- SSH 접근 가능한 대상 노드
- RPM 번들 준비 (오프라인 설치용)
- Harbor CA 인증서 (`roles/common/files/harbor-ca.crt`)

## 사용법

### Demo 환경

```bash
cd k8s-deploy

# 인벤토리 확인
ansible-inventory -i inventories/demo/hosts.yaml --list

# 연결 테스트
ansible -i inventories/demo/hosts.yaml all -m ping

# 클러스터 구축
ansible-playbook -i inventories/demo/hosts.yaml playbooks/build-cluster.yaml
```

### QA 환경

```bash
ansible-playbook -i inventories/qa/hosts.yaml playbooks/build-cluster.yaml
```

### 특정 Role만 실행

```bash
# 태그 사용
ansible-playbook -i inventories/demo/hosts.yaml playbooks/build-cluster.yaml --tags "common"

# 특정 호스트만
ansible-playbook -i inventories/demo/hosts.yaml playbooks/build-cluster.yaml --limit "masters"
```

## 실행 순서

| 순서 | Role/Task | 대상 노드 | 설명 |
|------|-----------|-----------|------|
| 1 | common | all | hostname, /etc/hosts, Harbor CA |
| 2 | k8s-preinstall | masters, workers | SELinux, swap, 커널 모듈, sysctl |
| 3 | k8s-install | masters, workers | CRI-O, kubelet, kubeadm, kubectl |
| 4 | k8s-init (main) | masters | kubeadm init |
| 5 | k8s-oss (calico) | masters | CNI 설치 (Worker join 전 필수) |
| 6 | k8s-init (join) | workers | kubeadm join |
| 7 | k8s-oss (나머지) | masters | Ingress, NFS, Metrics, ... |

## 주요 변수

### group_vars/all.yaml

| 변수 | 설명 | 예시 |
|------|------|------|
| `secloudit_version` | SECloudit 버전 | v2.0 |
| `k8s_version` | K8s 버전 (자동 계산) | 1.27.8 |
| `crio_version` | CRI-O 버전 (자동 계산) | 1.27 |
| `harbor_registry` | Harbor 주소 | harbor.example.com |
| `offline_install` | 오프라인 설치 여부 | true |
| `rpm_bundle_path` | RPM 번들 경로 | /opt/rpm-bundles |

### group_vars/masters.yaml

| 변수 | 설명 | 예시 |
|------|------|------|
| `pod_cidr` | Pod 네트워크 CIDR | 10.244.0.0/16 |
| `service_cidr` | Service 네트워크 CIDR | 10.96.0.0/12 |
| `api_server_endpoint` | API Server 엔드포인트 | haproxy:6443 |

### group_vars/haproxy.yaml

| 변수 | 설명 | v1.5 | v2.0+ |
|------|------|------|-------|
| `haproxy_api_frontend_port` | API 포트 | 26443 | 6443 |
| `haproxy_http_nodeport` | HTTP NodePort | 30180 | 30080 |
| `haproxy_https_nodeport` | HTTPS NodePort | 30181 | 30443 |

## Role 의존성

```
common
  └── k8s-preinstall
        └── k8s-install
              └── k8s-init (master)
                    └── k8s-oss (calico)
                          └── k8s-init (worker join)
                                └── k8s-oss (나머지)
```

## 멱등성 보장

- `kubeadm init`: `/etc/kubernetes/admin.conf` 존재 시 skip
- `kubeadm join`: `/etc/kubernetes/kubelet.conf` 존재 시 skip
- `kubeadm token`: 만료 시 자동 재생성

## 다음 단계

클러스터 구축 후 `secloudit-v{버전}` 프로젝트에서 애플리케이션을 배포합니다.
