# plan.md — secloudit-v2.6

> 작성일: 2026-03-17
> 상태: `구현 완료`
> 현재 Phase: Phase 1 - GitOps 파이프라인 인프라 구축

---

## 1. 목표

GitLab CI + ArgoCD 기반 GitOps 파이프라인 환경을 Ansible + Helm으로 구축한다.

### 성공 기준
- [ ] Harbor 레지스트리 정상 동작 (이미지 push/pull 가능)
- [ ] GitLab + Runner 정상 동작 (CI 파이프라인 실행 가능)
- [ ] ArgoCD App of Apps 구조 설정 완료
- [ ] GitLab CI → ArgoCD sync 트리거 동작

---

## 2. 트레이드오프

| 결정 | 선택 | 이유 |
|---|---|---|
| 배포 방식 | Helm | 멱등성 보장, 버전 관리 용이 |
| 멱등성 체크 | helm status | 릴리즈 존재 여부로 skip 처리 |
| values 관리 | values.yaml.j2 | Ansible 변수 주입 가능 |
| GitLab Runner executor | # TODO: 미확인 | docker vs kubernetes 결정 필요 |
| Harbor storage | # TODO: 미확인 | NFS vs PVC 결정 필요 |
| GitLab-ArgoCD 연동 | polling | GitLab CI가 secloudit-helm push → ArgoCD auto-sync |

---

## 3. 구현 체크리스트

### 덩어리 0: 프로젝트 기본 구조
<!-- 공통 파일 및 디렉토리 구조 생성 -->

- [x] 0-1: inventories/demo/hosts.yaml 생성
  - 파일: `inventories/demo/hosts.yaml`
  - 변경: k8s-master 호스트 정의
  ```yaml
  all:
    children:
      k8s_master:
        hosts:
          k8s-master:
            ansible_host: "{{ k8s_master_ip }}"  # TODO: 확인 필요
  ```

- [x] 0-2: group_vars/all.yaml 생성
  - 파일: `group_vars/all.yaml`
  - 변경: 공통 변수 정의 (kubeconfig, registry, 시크릿 참조)
  ```yaml
  # kubeconfig
  kubeconfig_path: /root/.kube/config

  # Registry
  harbor_registry: sample.harbor.com

  # Package source
  secloudit_package_repo: rnd-app.innogrid.com/inno-secloudit/secloudit-package.git

  # Helm release names
  harbor_release_name: harbor
  gitlab_release_name: gitlab
  argocd_release_name: argocd

  # Namespaces
  harbor_namespace: harbor
  gitlab_namespace: gitlab
  argocd_namespace: argocd

  # Secrets (vault 참조)
  harbor_admin_password: "{{ vault_harbor_admin_password }}"
  gitlab_root_password: "{{ vault_gitlab_root_password }}"
  argocd_admin_password: "{{ vault_argocd_admin_password }}"
  gitlab_runner_token: "{{ vault_gitlab_runner_token }}"
  ```

- [x] 0-3: playbooks/deploy-secloudit.yaml 생성
  - 파일: `playbooks/deploy-secloudit.yaml`
  - 변경: 4개 role 순서대로 실행
  ```yaml
  ---
  - name: Deploy GitOps Pipeline Infrastructure
    hosts: k8s_master
    become: true
    roles:
      - harbor
      - gitlab
      - argocd
      - gitops-pipeline
  ```

### 덩어리 A: Harbor 레지스트리 설치
<!-- Harbor Helm 설치 role -->

- [x] A-1: roles/harbor/defaults/main.yaml 생성
  - 파일: `roles/harbor/defaults/main.yaml`
  - 변경: Harbor 기본 변수 정의
  ```yaml
  ---
  harbor_chart_version: ""  # TODO: secloudit-package 확인 필요
  harbor_storage_class: ""  # TODO: NFS or PVC 확인 필요
  harbor_pvc_size: "50Gi"
  harbor_external_url: "https://{{ harbor_registry }}"
  ```

- [x] A-2: roles/harbor/templates/values.yaml.j2 생성
  - 파일: `roles/harbor/templates/values.yaml.j2`
  - 변경: Harbor Helm values 템플릿
  ```yaml
  expose:
    type: ingress
    tls:
      enabled: true
    ingress:
      hosts:
        core: {{ harbor_registry }}
  externalURL: {{ harbor_external_url }}
  harborAdminPassword: {{ harbor_admin_password }}
  persistence:
    enabled: true
    persistentVolumeClaim:
      registry:
        storageClass: {{ harbor_storage_class }}
        size: {{ harbor_pvc_size }}
  ```

- [x] A-3: roles/harbor/tasks/main.yaml 생성
  - 파일: `roles/harbor/tasks/main.yaml`
  - 변경: Harbor 설치 태스크
  ```yaml
  ---
  - name: kubeconfig 경로 확인
    ansible.builtin.stat:
      path: "{{ kubeconfig_path }}"
    register: kubeconfig_stat

  - name: kubeconfig 존재 확인
    ansible.builtin.fail:
      msg: "kubeconfig not found at {{ kubeconfig_path }}"
    when: not kubeconfig_stat.stat.exists

  - name: Harbor namespace 생성
    kubernetes.core.k8s:
      state: present
      definition:
        apiVersion: v1
        kind: Namespace
        metadata:
          name: "{{ harbor_namespace }}"
    environment:
      KUBECONFIG: "{{ kubeconfig_path }}"

  - name: Harbor Helm 릴리즈 존재 확인
    ansible.builtin.command:
      cmd: helm status {{ harbor_release_name }} -n {{ harbor_namespace }}
    environment:
      KUBECONFIG: "{{ kubeconfig_path }}"
    register: harbor_status
    changed_when: false
    failed_when: false

  - name: Harbor values 템플릿 생성
    ansible.builtin.template:
      src: values.yaml.j2
      dest: /tmp/harbor-values.yaml
      mode: '0600'
    when: harbor_status.rc != 0

  - name: Harbor Helm 설치
    ansible.builtin.command:
      cmd: >
        helm upgrade --install {{ harbor_release_name }}
        harbor/harbor
        -n {{ harbor_namespace }}
        -f /tmp/harbor-values.yaml
        --wait --timeout 10m
    environment:
      KUBECONFIG: "{{ kubeconfig_path }}"
    when: harbor_status.rc != 0

  - name: Harbor values 임시파일 삭제
    ansible.builtin.file:
      path: /tmp/harbor-values.yaml
      state: absent
  ```

### 덩어리 B: GitLab 설치
<!-- GitLab + Runner Helm 설치 role -->

- [x] B-1: roles/gitlab/defaults/main.yaml 생성
  - 파일: `roles/gitlab/defaults/main.yaml`
  - 변경: GitLab 기본 변수 정의
  ```yaml
  ---
  gitlab_chart_version: ""  # TODO: secloudit-package 확인 필요
  gitlab_runner_chart_version: ""  # TODO: secloudit-package 확인 필요
  gitlab_external_url: ""  # TODO: 확인 필요
  gitlab_runner_executor: ""  # TODO: docker or kubernetes 확인 필요
  ```

- [x] B-2: roles/gitlab/templates/values.yaml.j2 생성
  - 파일: `roles/gitlab/templates/values.yaml.j2`
  - 변경: GitLab Helm values 템플릿
  ```yaml
  global:
    hosts:
      domain: {{ gitlab_external_url }}
    initialRootPassword:
      secret: gitlab-initial-root-password
  certmanager:
    install: false
  nginx-ingress:
    enabled: false
  ```

- [x] B-3: roles/gitlab/templates/runner-values.yaml.j2 생성
  - 파일: `roles/gitlab/templates/runner-values.yaml.j2`
  - 변경: GitLab Runner Helm values 템플릿
  ```yaml
  gitlabUrl: {{ gitlab_external_url }}
  runnerRegistrationToken: {{ gitlab_runner_token }}
  runners:
    executor: {{ gitlab_runner_executor }}
  ```

- [x] B-4: roles/gitlab/tasks/main.yaml 생성
  - 파일: `roles/gitlab/tasks/main.yaml`
  - 변경: GitLab + Runner 설치 태스크
  ```yaml
  ---
  - name: kubeconfig 경로 확인
    ansible.builtin.stat:
      path: "{{ kubeconfig_path }}"
    register: kubeconfig_stat

  - name: kubeconfig 존재 확인
    ansible.builtin.fail:
      msg: "kubeconfig not found at {{ kubeconfig_path }}"
    when: not kubeconfig_stat.stat.exists

  - name: GitLab namespace 생성
    kubernetes.core.k8s:
      state: present
      definition:
        apiVersion: v1
        kind: Namespace
        metadata:
          name: "{{ gitlab_namespace }}"
    environment:
      KUBECONFIG: "{{ kubeconfig_path }}"

  - name: GitLab root password secret 생성
    kubernetes.core.k8s:
      state: present
      definition:
        apiVersion: v1
        kind: Secret
        metadata:
          name: gitlab-initial-root-password
          namespace: "{{ gitlab_namespace }}"
        type: Opaque
        stringData:
          password: "{{ gitlab_root_password }}"
    environment:
      KUBECONFIG: "{{ kubeconfig_path }}"

  - name: GitLab Helm 릴리즈 존재 확인
    ansible.builtin.command:
      cmd: helm status {{ gitlab_release_name }} -n {{ gitlab_namespace }}
    environment:
      KUBECONFIG: "{{ kubeconfig_path }}"
    register: gitlab_status
    changed_when: false
    failed_when: false

  - name: GitLab values 템플릿 생성
    ansible.builtin.template:
      src: values.yaml.j2
      dest: /tmp/gitlab-values.yaml
      mode: '0600'
    when: gitlab_status.rc != 0

  - name: GitLab Helm 설치
    ansible.builtin.command:
      cmd: >
        helm upgrade --install {{ gitlab_release_name }}
        gitlab/gitlab
        -n {{ gitlab_namespace }}
        -f /tmp/gitlab-values.yaml
        --wait --timeout 15m
    environment:
      KUBECONFIG: "{{ kubeconfig_path }}"
    when: gitlab_status.rc != 0

  - name: GitLab Runner values 템플릿 생성
    ansible.builtin.template:
      src: runner-values.yaml.j2
      dest: /tmp/gitlab-runner-values.yaml
      mode: '0600'

  - name: GitLab Runner Helm 설치
    ansible.builtin.command:
      cmd: >
        helm upgrade --install gitlab-runner
        gitlab/gitlab-runner
        -n {{ gitlab_namespace }}
        -f /tmp/gitlab-runner-values.yaml
        --wait --timeout 5m
    environment:
      KUBECONFIG: "{{ kubeconfig_path }}"

  - name: GitLab 임시파일 삭제
    ansible.builtin.file:
      path: "{{ item }}"
      state: absent
    loop:
      - /tmp/gitlab-values.yaml
      - /tmp/gitlab-runner-values.yaml
  ```

### 덩어리 C: ArgoCD 설치
<!-- ArgoCD Helm 설치 + App of Apps 설정 role -->

- [x] C-1: roles/argocd/defaults/main.yaml 생성
  - 파일: `roles/argocd/defaults/main.yaml`
  - 변경: ArgoCD 기본 변수 정의
  ```yaml
  ---
  argocd_chart_version: ""  # TODO: secloudit-package 확인 필요
  argocd_server_url: ""  # TODO: 확인 필요
  argocd_app_of_apps_repo: ""  # TODO: secloudit-package 구조 확인 필요
  argocd_app_of_apps_path: ""  # TODO: secloudit-package 구조 확인 필요
  ```

- [x] C-2: roles/argocd/templates/values.yaml.j2 생성
  - 파일: `roles/argocd/templates/values.yaml.j2`
  - 변경: ArgoCD Helm values 템플릿
  ```yaml
  server:
    extraArgs:
      - --insecure
    ingress:
      enabled: true
      hosts:
        - {{ argocd_server_url }}
  configs:
    secret:
      argocdServerAdminPassword: {{ argocd_admin_password | password_hash('bcrypt') }}
  ```

- [x] C-3: roles/argocd/templates/app-of-apps.yaml.j2 생성
  - 파일: `roles/argocd/templates/app-of-apps.yaml.j2`
  - 변경: App of Apps 루트 애플리케이션 정의
  ```yaml
  apiVersion: argoproj.io/v1alpha1
  kind: Application
  metadata:
    name: app-of-apps
    namespace: {{ argocd_namespace }}
  spec:
    project: default
    source:
      repoURL: {{ argocd_app_of_apps_repo }}
      targetRevision: HEAD
      path: {{ argocd_app_of_apps_path }}
    destination:
      server: https://kubernetes.default.svc
      namespace: {{ argocd_namespace }}
    syncPolicy:
      automated:
        prune: true
        selfHeal: true
  ```

- [x] C-4: roles/argocd/tasks/main.yaml 생성
  - 파일: `roles/argocd/tasks/main.yaml`
  - 변경: ArgoCD 설치 + App of Apps 설정 태스크
  ```yaml
  ---
  - name: kubeconfig 경로 확인
    ansible.builtin.stat:
      path: "{{ kubeconfig_path }}"
    register: kubeconfig_stat

  - name: kubeconfig 존재 확인
    ansible.builtin.fail:
      msg: "kubeconfig not found at {{ kubeconfig_path }}"
    when: not kubeconfig_stat.stat.exists

  - name: ArgoCD namespace 생성
    kubernetes.core.k8s:
      state: present
      definition:
        apiVersion: v1
        kind: Namespace
        metadata:
          name: "{{ argocd_namespace }}"
    environment:
      KUBECONFIG: "{{ kubeconfig_path }}"

  - name: ArgoCD Helm 릴리즈 존재 확인
    ansible.builtin.command:
      cmd: helm status {{ argocd_release_name }} -n {{ argocd_namespace }}
    environment:
      KUBECONFIG: "{{ kubeconfig_path }}"
    register: argocd_status
    changed_when: false
    failed_when: false

  - name: ArgoCD values 템플릿 생성
    ansible.builtin.template:
      src: values.yaml.j2
      dest: /tmp/argocd-values.yaml
      mode: '0600'
    when: argocd_status.rc != 0

  - name: ArgoCD Helm 설치
    ansible.builtin.command:
      cmd: >
        helm upgrade --install {{ argocd_release_name }}
        argo/argo-cd
        -n {{ argocd_namespace }}
        -f /tmp/argocd-values.yaml
        --wait --timeout 10m
    environment:
      KUBECONFIG: "{{ kubeconfig_path }}"
    when: argocd_status.rc != 0

  - name: ArgoCD 배포 완료 대기
    ansible.builtin.command:
      cmd: kubectl wait --for=condition=Available deployment --all -n {{ argocd_namespace }} --timeout=300s
    environment:
      KUBECONFIG: "{{ kubeconfig_path }}"
    changed_when: false

  - name: App of Apps manifest 생성
    ansible.builtin.template:
      src: app-of-apps.yaml.j2
      dest: /tmp/app-of-apps.yaml
      mode: '0644'

  - name: App of Apps 적용
    kubernetes.core.k8s:
      state: present
      src: /tmp/app-of-apps.yaml
    environment:
      KUBECONFIG: "{{ kubeconfig_path }}"

  - name: ArgoCD 임시파일 삭제
    ansible.builtin.file:
      path: "{{ item }}"
      state: absent
    loop:
      - /tmp/argocd-values.yaml
      - /tmp/app-of-apps.yaml
  ```

### 덩어리 D: GitOps Pipeline 연동
<!-- GitLab CI → secloudit-helm push → ArgoCD polling 방식 -->

- [x] D-1: roles/gitops-pipeline/defaults/main.yaml 생성
  - 파일: `roles/gitops-pipeline/defaults/main.yaml`
  - 변경: 파이프라인 연동 변수 정의 (polling 방식 확정)
  ```yaml
  ---
  # 연동 방식: polling (GitLab CI가 secloudit-helm push → ArgoCD auto-sync)
  gitlab_argocd_sync_method: "polling"

  # secloudit-helm 레포 (ArgoCD가 watching)
  secloudit_helm_repo: "rnd-app.innogrid.com/inno-secloudit/secloudit-helm.git"
  secloudit_helm_repo_url: "https://{{ secloudit_helm_repo }}"
  ```

- [x] D-2: roles/gitops-pipeline/templates/repository.yaml.j2 생성
  - 파일: `roles/gitops-pipeline/templates/repository.yaml.j2`
  - 변경: ArgoCD에 secloudit-helm 레포 등록
  ```yaml
  apiVersion: v1
  kind: Secret
  metadata:
    name: secloudit-helm-repo
    namespace: {{ argocd_namespace }}
    labels:
      argocd.argoproj.io/secret-type: repository
  stringData:
    type: git
    url: {{ secloudit_helm_repo_url }}
    # TODO: GitLab 인증 정보 (username/password 또는 SSH key)
  ```

- [x] D-3: roles/gitops-pipeline/templates/applicationset.yaml.j2 생성
  - 파일: `roles/gitops-pipeline/templates/applicationset.yaml.j2`
  - 변경: 브랜치별 ApplicationSet 설정 (global.branchSuffix 파라미터)
  ```yaml
  apiVersion: argoproj.io/v1alpha1
  kind: ApplicationSet
  metadata:
    name: secloudit-apps
    namespace: {{ argocd_namespace }}
  spec:
    generators:
      - git:
          repoURL: {{ secloudit_helm_repo_url }}
          revision: HEAD
          directories:
            - path: "charts/*"
    template:
      metadata:
        name: '{{`{{path.basename}}`}}'
      spec:
        project: default
        source:
          repoURL: {{ secloudit_helm_repo_url }}
          targetRevision: HEAD
          path: '{{`{{path}}`}}'
          helm:
            parameters:
              - name: global.branchSuffix
                value: '{{`{{path.basename}}`}}'
        destination:
          server: https://kubernetes.default.svc
          namespace: '{{`{{path.basename}}`}}'
        syncPolicy:
          automated:
            prune: true
            selfHeal: true
  ```

- [x] D-4: roles/gitops-pipeline/templates/gitlab-ci-template.yaml.j2 생성
  - 파일: `roles/gitops-pipeline/templates/gitlab-ci-template.yaml.j2`
  - 변경: GitLab CI 템플릿 (secloudit-helm values.yaml 업데이트 패턴)
  ```yaml
  # .gitlab-ci.yml template for secloudit projects
  # 연동 방식: docker build → harbor push → secloudit-helm values.yaml 업데이트 → ArgoCD auto-sync

  stages:
    - build
    - update-helm

  variables:
    HARBOR_REGISTRY: {{ harbor_registry }}
    SECLOUDIT_HELM_REPO: {{ secloudit_helm_repo }}

  build:
    stage: build
    script:
      - docker build -t ${HARBOR_REGISTRY}/${CI_PROJECT_NAME}:${CI_COMMIT_SHORT_SHA} .
      - docker push ${HARBOR_REGISTRY}/${CI_PROJECT_NAME}:${CI_COMMIT_SHORT_SHA}
    only:
      - main
      - develop

  update-helm:
    stage: update-helm
    script:
      - git clone https://${SECLOUDIT_HELM_REPO} secloudit-helm
      - cd secloudit-helm/charts/${CI_PROJECT_NAME}
      - sed -i "s/tag:.*/tag: ${CI_COMMIT_SHORT_SHA}/" values.yaml
      - git add values.yaml
      - git commit -m "ci: update ${CI_PROJECT_NAME} image tag to ${CI_COMMIT_SHORT_SHA}"
      - git push origin HEAD
    only:
      - main
      - develop
  ```

- [x] D-5: roles/gitops-pipeline/tasks/main.yaml 생성
  - 파일: `roles/gitops-pipeline/tasks/main.yaml`
  - 변경: GitLab CI → ArgoCD 연동 설정 태스크 (polling 방식)
  ```yaml
  ---
  - name: kubeconfig 경로 확인
    ansible.builtin.stat:
      path: "{{ kubeconfig_path }}"
    register: kubeconfig_stat

  - name: kubeconfig 존재 확인
    ansible.builtin.fail:
      msg: "kubeconfig not found at {{ kubeconfig_path }}"
    when: not kubeconfig_stat.stat.exists

  - name: secloudit-helm repository secret 생성
    ansible.builtin.template:
      src: repository.yaml.j2
      dest: /tmp/secloudit-helm-repo.yaml
      mode: '0600'

  - name: ArgoCD에 secloudit-helm 레포 등록
    kubernetes.core.k8s:
      state: present
      src: /tmp/secloudit-helm-repo.yaml
    environment:
      KUBECONFIG: "{{ kubeconfig_path }}"

  - name: ApplicationSet manifest 생성
    ansible.builtin.template:
      src: applicationset.yaml.j2
      dest: /tmp/secloudit-applicationset.yaml
      mode: '0644'

  - name: ApplicationSet 적용 (브랜치별 배포 설정)
    kubernetes.core.k8s:
      state: present
      src: /tmp/secloudit-applicationset.yaml
    environment:
      KUBECONFIG: "{{ kubeconfig_path }}"

  - name: GitLab CI 템플릿 디렉토리 생성
    ansible.builtin.file:
      path: /opt/secloudit/gitlab-ci-templates
      state: directory
      mode: '0755'

  - name: GitLab CI 템플릿 배포
    ansible.builtin.template:
      src: gitlab-ci-template.yaml.j2
      dest: /opt/secloudit/gitlab-ci-templates/secloudit-pipeline.yml
      mode: '0644'

  - name: 임시파일 삭제
    ansible.builtin.file:
      path: "{{ item }}"
      state: absent
    loop:
      - /tmp/secloudit-helm-repo.yaml
      - /tmp/secloudit-applicationset.yaml
  ```

---

## 4. 미결 사항

| 항목 | 관련 덩어리 | 상태 |
|---|---|---|
| k8s-master IP | 0 | # TODO: k8s-cluster Terraform output 확인 |
| Harbor chart 버전 | A | # TODO: secloudit-package 확인 |
| Harbor storage 설정 | A | # TODO: NFS or PVC 결정 |
| GitLab chart 버전 | B | # TODO: secloudit-package 확인 |
| GitLab Runner executor | B | # TODO: docker or kubernetes 결정 |
| ArgoCD chart 버전 | C | # TODO: secloudit-package 확인 |
| App of Apps 저장소 구조 | C, D | ✅ secloudit-helm 레포 (applicationset.yaml 최상단) |
| GitLab-ArgoCD 연동 방식 | D | ✅ polling (secloudit-helm push → ArgoCD auto-sync) |

---

## 5. 인라인 메모란

<!--
  사람이 검토하면서 메모를 남기는 공간입니다.
  Claude는 3단계에서 이 메모를 반영하여 plan.md를 업데이트합니다.

  예시:
  [메모] A-2: Harbor storage는 PVC 사용
  [메모] B-4: GitLab Runner는 kubernetes executor 사용
  [질문] D-2: webhook 방식으로 할지?
-->

(검토 메모를 여기에 작성)

---

## 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-03-17 | 초안 작성 — 4개 role 구현 계획 수립 |
| 2026-03-17 | 덩어리 D 수정 — polling 방식 확정, secloudit-helm 레포 구조 반영 |
| 2026-03-17 | 전체 구현 완료 — syntax-check 및 list-tasks 검증 통과 |
