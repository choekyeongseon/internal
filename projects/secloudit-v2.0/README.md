# SECloudit v2.0 배포 자동화

SECloudit v2.0 솔루션 컴포넌트를 Ansible로 배포하는 프로젝트입니다.

## 사전 조건

- Ansible 2.9+
- k8s-cluster 프로젝트 완료 (K8s 클러스터 구축 완료 상태)
- Docker + docker-compose 설치됨 (Console VM)
- kubectl 설치됨 (k8s-master)
- Harbor 이미지 레지스트리 접근 가능 (sample.harbor.com)

## 디렉토리 구조

```
secloudit-v2.0/
├── ansible.cfg
├── inventories/
│   ├── demo/hosts.yaml
│   └── qa/hosts.yaml
├── group_vars/
│   └── all.yaml
├── roles/
│   ├── secloudit-console/    # Console VM (docker-compose)
│   ├── fluentd-agent/        # in-cluster FluentD DaemonSet
│   ├── argocd/               # in-cluster ArgoCD
│   ├── tekton/               # in-cluster Tekton
│   └── istio/                # in-cluster Istio
└── playbooks/
    └── deploy-secloudit.yaml
```

## 설치 순서

```
1. Console VM    → docker-compose (7개 컴포넌트)
2. FluentD Agent → kubectl apply (DaemonSet)
3. ArgoCD        → kubectl apply
4. Tekton        → kubectl apply (Pipelines + Triggers)
5. Istio         → kubectl apply (base + istiod)
```

## 사용법

### 전체 배포

```bash
ansible-playbook -i inventories/demo/hosts.yaml playbooks/deploy-secloudit.yaml
```

### 특정 role만 배포

```bash
# Console VM만
ansible-playbook -i inventories/demo/hosts.yaml playbooks/deploy-secloudit.yaml --tags console

# in-cluster 컴포넌트만
ansible-playbook -i inventories/demo/hosts.yaml playbooks/deploy-secloudit.yaml --limit k8s-master
```

### Syntax 확인

```bash
ansible-playbook --syntax-check playbooks/deploy-secloudit.yaml
```

### Dry-run (체크 모드)

```bash
ansible-playbook -i inventories/demo/hosts.yaml playbooks/deploy-secloudit.yaml --check
```

## 주요 변수

### group_vars/all.yaml

| 변수 | 설명 | 기본값 |
|---|---|---|
| `k8s_version` | K8s 버전 선택 (1.24/1.25/1.26/1.27) | `1.27` |
| `registry_host` | 이미지 레지스트리 주소 | `sample.harbor.com` |
| `kubeconfig_path` | kubeconfig 경로 | `/etc/kubernetes/admin.conf` |

### Console VM 컴포넌트 포트

| 컴포넌트 | 포트 |
|---|---|
| MySQL | 3306 |
| MongoDB | 27017 |
| FluentD Forward | 24224 |
| GitLab HTTP | 8080 |
| GitLab HTTPS | 8443 |
| GitLab SSH | 8022 |
| ChartMuseum | 5080 |
| gitlabci-module API | 8093 |
| gitlabci-module Metrics | 9091 |
| secloudit-console | 9080 |

### OSS 버전

| 컴포넌트 | 버전 |
|---|---|
| K8s | 1.24.14 / 1.25.10 / 1.26.11 / 1.27.8 |
| Calico | 3.26.3 |
| GitLab CE | 15.11.3-ce.0 |
| GitLab Runner | v15.11.1 |
| ChartMuseum | v0.16.0 |
| MySQL | 8.0 |
| MongoDB | 5.0 |
| Tekton Pipeline | 0.44.0 |
| Tekton Triggers | 0.22.0 |

## 시크릿 관리

시크릿은 Ansible Vault로 관리합니다. 평문 금지.

```yaml
# group_vars/all.yaml
mysql_root_password: "{{ vault_mysql_root_password }}"
mongodb_root_password: "{{ vault_mongodb_root_password }}"
harbor_admin_password: "{{ vault_harbor_admin_password }}"
gitlab_root_password: "{{ vault_gitlab_root_password }}"
chartmuseum_password: "{{ vault_chartmuseum_password }}"
argocd_admin_password: "{{ vault_argocd_admin_password }}"
secloudit_admin_password: "{{ vault_secloudit_admin_password }}"
```

Vault 파일 생성:

```bash
ansible-vault create group_vars/vault.yaml
```

## v1.5 대비 변경사항

| 항목 | v1.5 | v2.0 |
|---|---|---|
| 컨테이너 런타임 | podman-compose | docker-compose |
| HAProxy API 포트 | 26443 | 6443 |
| K8s 버전 | 1.23.x 고정 | 1.24~1.27 선택 |
| Calico | - | 3.26.3 |
| Tekton Pipeline | 0.28.3 | 0.44.0 |
| Tekton Triggers | 0.18.0 | 0.22.0 |
| 추가 VM 컴포넌트 | - | GitLab, ChartMuseum, gitlabci-module |
| 추가 in-cluster | - | ArgoCD, Istio |
| Console VM 통합 | SE노드 + Logging 분리 | 7개 컴포넌트 통합 |

## TODO

배포 전 확인 필요한 항목:

- [ ] Console VM 실제 IP
- [ ] k8s-master IP (Terraform output)
- [ ] FluentD FLUENT_FORWARD_HOST 값
- [ ] FluentD CLUSTER_DIVIDE_VALUE 값
- [ ] ArgoCD 버전 확정 후 manifest 교체
- [ ] Istio 버전 확정 후 manifest 교체
- [ ] Tekton manifest 이미지 주소 치환
- [ ] gitlabci-module JWT secret 등 상세 설정

## 트러블슈팅

### Docker 관련

```bash
# Console VM에서 컨테이너 상태 확인
docker ps -a
docker-compose -f /opt/secloudit/docker-compose.yaml logs -f
```

### Kubernetes 관련

```bash
# k8s-master에서 리소스 확인
kubectl get pods -A
kubectl get daemonset -n kube-system
kubectl get deployment -n argocd
kubectl get deployment -n tekton-pipelines
kubectl get deployment -n istio-system
```

## 참고

- 리서치 문서: `.ai/research.md`
- 구현 계획: `.ai/plan.md`
- 세션 로그: `.ai/logs/`
