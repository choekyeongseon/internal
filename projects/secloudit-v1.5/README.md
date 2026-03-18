# SECloudit v1.5 배포 자동화

SECloudit v1.5 솔루션 컴포넌트를 Ansible로 배포합니다.

## 사전 조건

- Ansible 2.9+
- 대상 VM: Rocky Linux 9.1 (Podman 기본 설치)
- K8s 클러스터 구축 완료 (k8s-cluster 프로젝트)
- Harbor 이미지 로드 완료 (sample.harbor.com)

## 배포 구조

```
[VM 배포 — podman-compose]
SE 노드 VM          : MySQL (3306) → SECloudit Console (9080)
Logging VM          : MongoDB (27017) → FluentD Forward (24224)

[in-cluster 배포 — kubectl apply]
FluentD Agent       : DaemonSet (K8s 노드 로그 수집)
Tekton Pipelines    : v0.28.3
Tekton Triggers     : v0.18.0
```

## 실행 순서

```
1. SE 노드 VM     — MySQL 구동 → healthy 확인 → SECloudit Console 구동
2. Logging VM     — MongoDB 구동 → FluentD Forward 구동
3. in-cluster     — FluentD Agent DaemonSet 배포
4. in-cluster     — Tekton Pipelines → Tekton Triggers 배포
```

## 사용법

```bash
# demo 환경 배포
ansible-playbook -i inventories/demo/hosts.yaml playbooks/deploy-secloudit.yaml

# qa 환경 배포
ansible-playbook -i inventories/qa/hosts.yaml playbooks/deploy-secloudit.yaml

# vault 비밀번호 입력
ansible-playbook -i inventories/demo/hosts.yaml playbooks/deploy-secloudit.yaml --ask-vault-pass
```

## 주요 변수

### group_vars/all.yaml

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `registry_host` | 이미지 레지스트리 호스트 | sample.harbor.com |
| `mysql_version` | MySQL 버전 | 8.0.31 |
| `mongodb_version` | MongoDB 버전 | 5.0.14 |
| `fluentd_version` | FluentD 버전 | 1.13 |
| `tekton_pipeline_version` | Tekton Pipelines 버전 | 0.28.3 |
| `tekton_triggers_version` | Tekton Triggers 버전 | 0.18.0 |
| `kubeconfig_path` | kubeconfig 경로 | /etc/kubernetes/admin.conf |

### 시크릿 (Ansible Vault)

| 변수 | 설명 |
|------|------|
| `vault_mysql_root_password` | MySQL root 비밀번호 |
| `vault_mongodb_root_password` | MongoDB root 비밀번호 |
| `vault_secloudit_admin_password` | SECloudit 관리자 비밀번호 |

## 디렉토리 구조

```
secloudit-v1.5/
├── ansible.cfg
├── inventories/
│   ├── demo/hosts.yaml
│   └── qa/hosts.yaml
├── group_vars/
│   └── all.yaml
├── roles/
│   ├── secloudit-console/    # MySQL + Console (podman-compose)
│   ├── secloudit-logging/    # MongoDB + FluentD Forward (podman-compose)
│   ├── fluentd-agent/        # FluentD DaemonSet (kubectl apply)
│   └── tekton/               # Tekton Pipelines + Triggers (kubectl apply)
└── playbooks/
    └── deploy-secloudit.yaml
```

## 미결 사항

> TODO: 배포 전 확인 필요

- FluentD Agent `FLUENT_FORWARD_HOST` 값 (Logging VM IP)
- FluentD `CLUSTER_DIVIDE_VALUE` (클러스터 구분자)
- httpd https proxy 인증서 경로
- Tekton manifest 이미지 주소 치환 (gcr.io → 내부 레지스트리)
- SE노드, Logging VM 실제 IP 주소
