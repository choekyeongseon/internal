# research.md — secloudit-v2.6

> 작성일: 2026-03-17
> 상태: `진행 중`
> 목적: GitOps 파이프라인 환경 구축을 위한 사전 리서치

---

## 1. 자동화 대상

### 무엇을 만드는가
- GitOps 파이프라인 환경 구축 (Harbor + GitLab + ArgoCD)
- GitLab CI → ArgoCD 연동 자동화
- **중요**: 솔루션 OSS 배포는 이 파이프라인이 완성된 후 단계임
  - 이 프로젝트의 산출물은 "배포된 OSS"가 아닌 "동작하는 GitOps 파이프라인"

### 핵심 제약 조건
- v1.5/v2.0/v2.3과 다른 패러다임: Ansible이 직접 배포하지 않음
- Ansible은 GitOps 파이프라인 인프라만 구축
- 이후 모든 OSS 배포는 구축된 파이프라인(GitLab CI + ArgoCD)이 담당

---

## 2. 기술 스택 및 버전

| 항목 | 버전 | 비고 |
|---|---|---|
| Kubernetes | v1.35 | k8s-cluster 프로젝트에서 구축 완료 |
| Ansible | - | 파이프라인 인프라 구축 도구 |
| Helm | - | 패키지 배포 |
| ArgoCD | # TODO: secloudit-package 확인 필요 | GitOps CD |
| GitLab | # TODO: secloudit-package 확인 필요 | SCM/CI |
| GitLab Runner | # TODO: secloudit-package 확인 필요 | CI 실행기 |
| Harbor | # TODO: secloudit-package 확인 필요 | 이미지 레지스트리 |

---

## 3. 아키텍처

### GitOps 플로우
```
개발자 push → GitLab CI → ArgoCD → K8s
```

### 컴포넌트 관계도
```
                    ┌─────────────┐
                    │   Harbor    │
                    │ (Registry)  │
                    └──────┬──────┘
                           │ pull image
    ┌──────────────────────┼──────────────────────┐
    │                      │                      │
    ▼                      ▼                      │
┌────────┐   trigger   ┌────────┐   deploy   ┌────────┐
│ GitLab │ ──────────► │ ArgoCD │ ─────────► │  K8s   │
│  CI    │             │        │            │Cluster │
└────────┘             └────────┘            └────────┘
    │                      ▲
    │                      │
    └──────── push ────────┘
         (Helm values)
```

### 주요 모듈 역할
- `harbor/`: Harbor 레지스트리 설치 — 이미지 저장소
- `gitlab/`: GitLab 설치 + Runner 설정 — SCM 및 CI
- `argocd/`: ArgoCD 설치 + App of Apps 구조 설정 — GitOps CD
- `gitops-pipeline/`: GitLab CI → ArgoCD 연동 파이프라인 설정

---

## 4. 핵심 변수/설정값

### 레지스트리 설정
```yaml
harbor_registry: sample.harbor.com
```

### kubeconfig 설정
```yaml
kubeconfig_path: # TODO: k8s-cluster Terraform output 확인 필요
```

### GitLab/ArgoCD 연동 설정
```yaml
gitlab_url: # TODO: 확인 필요
argocd_server: # TODO: 확인 필요
gitlab_argocd_sync_method: # TODO: webhook vs polling 확인 필요
```

### 패키지 소스
```yaml
secloudit_package_repo: rnd-app.innogrid.com/inno-secloudit/secloudit-package.git
```

---

## 5. 의존성 및 순서

### 4단계 설치 순서 (변경 금지)
1. **Harbor** — 레지스트리 먼저 (이미지 pull 필요)
2. **GitLab** — SCM/CI
3. **ArgoCD** — GitOps CD
4. **gitops-pipeline** — GitLab CI → ArgoCD 연동 설정

### 의존성 관계
```
Harbor ◄─── GitLab CI (이미지 push)
  │
  └─────► ArgoCD (이미지 pull)
              │
              └───► K8s (배포)

GitLab ◄─── gitops-pipeline (CI 설정)
   │
   └────► ArgoCD (sync 트리거)
```

### 선행 조건
- k8s-cluster 프로젝트 완료 (K8s v1.35 클러스터 구축 완료)

---

## 6. 시크릿 항목 (값 기재 금지)

> **값 기재 금지** — 항목명만 나열

| 항목 | 용도 | 저장 위치 |
|---|---|---|
| `vault_argocd_admin_password` | ArgoCD 관리자 비밀번호 | Ansible Vault |
| `vault_gitlab_root_password` | GitLab root 비밀번호 | Ansible Vault |
| `vault_harbor_admin_password` | Harbor 관리자 비밀번호 | Ansible Vault |
| `vault_gitlab_runner_token` | GitLab Runner 등록 토큰 | Ansible Vault |

---

## 7. 변경 영향 범위

### v2.3 대비 패러다임 전환
- **이전 (v1.5/v2.0/v2.3)**: Ansible이 직접 각 VM/K8s에 컴포넌트 배포
- **현재 (v2.6)**: Ansible이 GitOps 파이프라인을 구축 → 이후 배포는 파이프라인이 담당

### 이 파이프라인의 역할
- 이 프로젝트가 완료되면, 이후 모든 OSS 배포의 기반이 됨
- SECloudit 솔루션 컴포넌트들은 이 파이프라인을 통해 배포

### 영향받는 영역
- 모든 후속 배포 자동화
- CI/CD 워크플로우 전체
- 개발/운영 배포 프로세스

---

## 8. 미확인 항목

| 항목 | 영향 범위 | 확인 방법 |
|---|---|---|
| k8s-master IP | 전체 인프라 연결 | k8s-cluster Terraform output 확인 |
| ArgoCD App of Apps 저장소 구조 | ArgoCD 설정 | secloudit-package 저장소 확인 |
| GitLab CI → ArgoCD 연동 방식 | gitops-pipeline 구현 | webhook vs polling 결정 필요 |
| 각 컴포넌트 Helm 차트 버전 | 설치 스크립트 | secloudit-package 저장소 확인 |
| Harbor storage 설정 | Harbor 설치 | NFS or PVC 결정 필요 |
| GitLab Runner executor 방식 | GitLab CI 실행 | docker/kubernetes 결정 필요 |

---

## 메모

- 이 프로젝트는 "인프라 자동화"가 아닌 "인프라 자동화 환경의 자동화"
- 결과물인 GitOps 파이프라인이 이후 모든 배포의 Single Source of Truth가 됨
