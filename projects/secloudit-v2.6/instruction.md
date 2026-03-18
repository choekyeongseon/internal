아래 순서대로 진행해라.
아직 구현하지 마라. 각 단계 완료 후 결과를 보고하고 다음 단계로 넘어가라.

---

## 1단계 — 프로젝트 초기화

프레임워크 루트에서 실행: (이미 완료)

완료 후 생성된 구조를 보고해라.

---

## 2단계 — CLAUDE.md 섹션 2 채우기

projects/secloudit-v2.6/.ai/CLAUDE.md 의 섹션 2를 아래 내용으로 채워라.
섹션 1은 절대 수정하지 마라.

### 프로젝트 개요
- 프로젝트명: secloudit-v2.6
- 목적: GitLab CI + ArgoCD 기반 GitOps 파이프라인 환경 구축
  (SECloudit v2.6은 미릴리즈 — 이 프로젝트는 솔루션 배포 자동화가 아닌
  CI/CD 환경 자체를 셋업하는 프로젝트)
- 기술스택: Ansible, Helm, ArgoCD, GitLab CI
- 선행 조건: k8s-cluster 프로젝트 완료 (K8s v1.35 클러스터 구축 완료)
- 이미지 레지스트리: sample.harbor.com (모든 프로젝트 공통)
- 패키지 소스: rnd-app.innogrid.com/inno-secloudit/secloudit-package.git

### 프로젝트 성격 (중요)
이 프로젝트는 v1.5/v2.0/v2.3과 다르다.
- v1.5/v2.0/v2.3: Ansible이 직접 각 VM/K8s에 컴포넌트를 배포
- v2.6: Ansible이 GitOps 파이프라인(GitLab CI + ArgoCD)을 구축하고,
  이후 모든 OSS 배포는 이 파이프라인이 담당

즉 이 프로젝트의 결과물은 "배포된 OSS"가 아닌 "동작하는 GitOps 파이프라인"이다.

### 핵심 산출물
1. ArgoCD 설치 및 App of Apps 구조 설정
2. GitLab 설치 및 GitLab Runner 설정
3. Harbor 레지스트리 설치
4. GitLab CI → ArgoCD 연동 파이프라인
    - GitLab CI: 코드 변경 감지 → 이미지 빌드 → ArgoCD sync 트리거
    - ArgoCD: secloudit-package Helm 차트 → K8s 배포

### 배포 방식 (GitOps)
- Helm Chart 기반 (values.yaml.j2로 관리)
- ArgoCD가 secloudit-package 저장소의 Helm 차트를 Watch
- GitLab CI가 변경 사항 push 시 ArgoCD sync 트리거

### 레포지토리 구조
secloudit-v2.6/
├── inventories/
│   ├── demo/hosts.yaml      ← k8s-master
│   └── qa/hosts.yaml
├── group_vars/
│   └── all.yaml
├── roles/
│   ├── argocd/              ← ArgoCD 설치 + App of Apps 설정 (1순위)
│   ├── gitlab/              ← GitLab 설치 + Runner 설정
│   ├── harbor/              ← Harbor 레지스트리 설치
│   └── gitops-pipeline/     ← GitLab CI → ArgoCD 연동 파이프라인 설정
└── playbooks/
└── deploy-secloudit.yaml

### 설치 순서 (변경 금지)

Harbor       — 레지스트리 먼저 (이미지 pull 필요)
GitLab       — SCM/CI
ArgoCD       — GitOps CD
gitops-pipeline — GitLab CI → ArgoCD 연동 설정


### 코딩 규칙
- Ansible: 모든 태스크에 name: 필수
- 멱등성 필수 — helm status로 릴리즈 존재 확인 후 skip
- 시크릿: 절대 평문 금지, vault_ prefix 변수로만 참조
- Helm values: templates/ 에서 values.yaml.j2로 관리
- in-cluster 태스크: kubectl/helm 전 kubeconfig 경로 확인 필수

### 시크릿 항목 (값 기재 금지)
- vault_argocd_admin_password
- vault_gitlab_root_password
- vault_harbor_admin_password
- vault_gitlab_runner_token

### 미확인 항목 (# TODO — 임의 결정 금지)
- k8s-master IP (k8s-cluster Terraform output)
- ArgoCD App of Apps 저장소 구조 (secloudit-package 확인 필요)
- GitLab CI → ArgoCD 연동 방식 (webhook vs polling)
- 각 컴포넌트 Helm 차트 버전 (secloudit-package 저장소 확인 필요)
- Harbor storage 설정 (NFS or PVC)
- GitLab Runner executor 방식 (docker/kubernetes)

---

## 3단계 — research.md 채우기

아래 8개 섹션으로 작성해라:

1. 자동화 대상
    - GitOps 파이프라인 환경 구축 (Harbor + GitLab + ArgoCD)
    - GitLab CI → ArgoCD 연동
    - 솔루션 OSS 배포는 이 파이프라인이 완성된 후 단계임을 명시

2. 기술 스택 및 버전
    - Ansible, Helm, ArgoCD, GitLab CI, Harbor
    - K8s v1.35
    - 각 컴포넌트 버전 (# TODO — secloudit-package 확인 필요)

3. 아키텍처
    - GitOps 플로우: 개발자 push → GitLab CI → ArgoCD → K8s
    - 컴포넌트 관계도 (Harbor ← GitLab CI → ArgoCD → K8s)

4. 핵심 변수/설정값
    - 레지스트리, kubeconfig, GitLab/ArgoCD 연동 설정

5. 의존성 및 순서
    - 4단계 설치 순서 + 의존성 관계

6. 시크릿 항목 (값 기재 금지)
    - vault_ 변수 4개

7. 변경 영향 범위
    - v2.3 대비 패러다임 전환 (Ansible 직접 배포 → GitOps)
    - 이 파이프라인이 이후 OSS 배포 전체의 기반이 됨

8. 미확인 항목

---

## 완료 기준

- [ ] projects/secloudit-v2.6/ 디렉토리 구조 생성
- [ ] .ai/CLAUDE.md 섹션 2 내용 채워짐 (섹션 1 변경 없음)
- [ ] .ai/research.md 8개 섹션 작성 완료
- [ ] git log에 초기 커밋 확인

완료 후 두 파일 주요 내용을 요약해서 보고하고 git commit 해라.