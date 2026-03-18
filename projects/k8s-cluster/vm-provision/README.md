# vm-provision

OpenStack에 K8s 클러스터용 VM을 프로비저닝하는 Terraform 모듈.

## 구조

```
vm-provision/
├── modules/
│   └── k8s-cluster/          # VM 프로비저닝 모듈
│       ├── main.tf           # compute 리소스 정의
│       ├── variables.tf      # 입력 변수
│       └── outputs.tf        # 출력값
├── environments/
│   ├── demo/                 # Demo 환경
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   └── qa/                   # QA 환경 (workspace 사용)
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars
├── versions.tf               # Provider 버전 설정
├── terraform.tfvars.example  # 변수 예시
└── README.md
```

## 사전 요구사항

- Terraform >= 1.0.0
- OpenStack 접근 권한 (환경변수 또는 clouds.yaml)
- SSH 키페어 등록 완료

## OpenStack 인증 설정

### 환경변수 사용

```bash
export OS_AUTH_URL="https://openstack.example.com:5000/v3"
export OS_USERNAME="admin"
export OS_PASSWORD="password"
export OS_PROJECT_NAME="my-project"
export OS_USER_DOMAIN_NAME="Default"
export OS_PROJECT_DOMAIN_NAME="Default"
```

### clouds.yaml 사용

```yaml
# ~/.config/openstack/clouds.yaml
clouds:
  openstack:
    auth:
      auth_url: https://openstack.example.com:5000/v3
      username: admin
      password: password
      project_name: my-project
      user_domain_name: Default
      project_domain_name: Default
```

## 사용법

### Demo 환경

```bash
cd environments/demo

# 초기화
terraform init

# 계획 확인
terraform plan

# 적용
terraform apply

# 삭제
terraform destroy
```

### QA 환경 (Workspace 사용)

```bash
cd environments/qa

# 초기화
terraform init

# 새 워크스페이스 생성 (Jira 티켓 기반)
terraform workspace new qa-ST-42

# 계획 확인
terraform plan

# 적용
terraform apply

# 삭제
terraform destroy

# 워크스페이스 삭제
terraform workspace select default
terraform workspace delete qa-ST-42
```

## 변수 목록

### 클러스터 식별

| 변수 | 설명 | 기본값 | 필수 |
|------|------|--------|------|
| `cluster_name` | 클러스터 이름 | - | O |
| `secloudit_version` | SECloudit 버전 (v1.5/v2.0/v2.3/v2.6) | - | O |
| `cluster_type` | 클러스터 타입 (all-in-one/separated) | separated | - |

### 노드 수

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `master_count` | 마스터 노드 수 | 1 |
| `worker_count` | 워커 노드 수 | 3 |
| `haproxy_count` | HAProxy 노드 수 | 1 |
| `nfs_count` | NFS 노드 수 | 1 |

### OpenStack 리소스

| 변수 | 설명 | 필수 |
|------|------|------|
| `flavor_master` | 마스터 노드 flavor | O |
| `flavor_worker` | 워커 노드 flavor | O |
| `flavor_haproxy` | HAProxy 노드 flavor | O |
| `flavor_nfs` | NFS 노드 flavor | O |
| `image_name` | VM 이미지 이름 | O |
| `network_name` | 네트워크 이름 | O |
| `keypair_name` | SSH 키페어 이름 | O |
| `security_groups` | 보안 그룹 목록 | - |

## 출력값

| 출력 | 설명 |
|------|------|
| `haproxy_ips` | HAProxy 노드 IP 목록 |
| `master_ips` | Master 노드 IP 목록 |
| `worker_ips` | Worker 노드 IP 목록 |
| `nfs_ips` | NFS 노드 IP 목록 |
| `cluster_info` | 클러스터 요약 정보 |

## Workspace 네이밍 규칙

| 환경 | Workspace 이름 | 예시 |
|------|----------------|------|
| Demo | default | - |
| QA | qa-{jira-ticket-id} | qa-ST-42 |

## 다음 단계

VM 프로비저닝 후 `k8s-deploy/` 디렉토리의 Ansible 플레이북으로 K8s 클러스터를 구축합니다.

```bash
cd ../k8s-deploy
ansible-playbook -i inventories/demo/hosts.yaml playbooks/build-cluster.yaml
```
