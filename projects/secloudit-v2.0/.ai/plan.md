# plan.md — secloudit-v2.0

> 작성일: 2026-03-16
> 상태: `완료`
> 현재 Phase: Phase 1 - SECloudit v2.0 배포 자동화

---

## 1. 목표

SECloudit v2.0 솔루션 컴포넌트를 Console VM에 docker-compose로 배포하고, K8s 클러스터에 OSS(FluentD Agent, ArgoCD, Tekton, Istio)를 kubectl apply로 배포한다.

### 성공 기준
- [ ] deploy-secloudit.yaml 실행 시 Console VM에 7개 컨테이너 정상 기동
- [ ] in-cluster 리소스 배포 완료 (FluentD Agent, ArgoCD, Tekton, Istio)
- [ ] 멱등성 보장 — 2회 연속 실행해도 오류 없음
- [ ] 설치 순서 준수 (Console VM → FluentD Agent → ArgoCD → Tekton → Istio)

---

## 2. 트레이드오프

| 결정 | 선택 | 이유 |
|---|---|---|
| 컨테이너 런타임 | Docker + docker-compose | v2.0 요구사항 (v1.5 podman에서 변경) |
| VM 통합 방식 | Console VM 1대에 7개 컴포넌트 통합 | 우리 환경 기준, 현장별 분리 가능 |
| Image Registry | 기존 Harbor (sample.harbor.com) | 모든 프로젝트 공통 |
| compose 파일 관리 | Jinja2 템플릿 (.j2) | 환경별 변수 주입 용이 |
| in-cluster 배포 방식 | kubectl apply (manifest) | Helm 없이 단순화, 오프라인 환경 고려 |
| K8s 버전 분기 | k8s_version_map 변수 | 1.24~1.27 선택 지원 |

---

## 3. 구현 체크리스트

### 덩어리 A: VM 환경 준비 (Ansible: 인벤토리 + 공통 변수)
<!-- 이 덩어리 = Claude Code 작업 지시 1회 단위 -->

- [x] A-1: 프로젝트 디렉토리 구조 생성
  - 파일: `secloudit-v2.0/`
  - 변경: inventories/, group_vars/, roles/, playbooks/ 생성

- [x] A-2: inventories/demo/hosts.yaml 작성
  - 파일: `inventories/demo/hosts.yaml`
  - 변경: 호스트 그룹 정의 (console-vm, k8s-master)
  ```yaml
  all:
    children:
      console-vm:
        hosts:
          console-01:
            ansible_host: "{{ console_vm_ip }}"  # TODO: 실제 IP 확인 필요
      k8s-master:
        hosts:
          k8s-master-01:
            ansible_host: "{{ k8s_master_ip }}"  # TODO: Terraform output
  ```

- [x] A-3: inventories/qa/hosts.yaml 작성
  - 파일: `inventories/qa/hosts.yaml`
  - 변경: qa 환경 인벤토리 (구조 동일, IP 다름)

- [x] A-4: group_vars/all.yaml 작성
  - 파일: `group_vars/all.yaml`
  - 변경: 공통 변수 정의 (K8s 버전 맵, 포트, 레지스트리, vault_ 참조)
  ```yaml
  # K8s 버전 분기
  k8s_version_map:
    "1.24": "1.24.14"
    "1.25": "1.25.10"
    "1.26": "1.26.11"
    "1.27": "1.27.8"
  k8s_version: "1.27"

  # Image Registry
  registry_host: "sample.harbor.com"
  registry_port: 443

  # OSS 버전
  calico_version: "3.26.3"
  gitlab_version: "15.11.3-ce.0"
  chartmuseum_version: "v0.16.0"
  tekton_pipeline_version: "0.44.0"
  tekton_triggers_version: "0.22.0"
  mysql_version: "8.0"
  mongodb_version: "5.0"

  # 포트 설정
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

  # 시크릿 (vault 참조)
  mysql_root_password: "{{ vault_mysql_root_password }}"
  mongodb_root_password: "{{ vault_mongodb_root_password }}"
  gitlab_root_password: "{{ vault_gitlab_root_password }}"
  # ... 기타 시크릿
  ```

- [x] A-5: playbooks/deploy-secloudit.yaml 기본 골격 작성
  - 파일: `playbooks/deploy-secloudit.yaml`
  - 변경: 플레이북 골격 (5단계 설치 순서 반영)

- [x] A-6: ansible.cfg 작성
  - 파일: `ansible.cfg`
  - 변경: roles_path, inventory 기본값 설정

### 덩어리 B: Console VM 컴포넌트 배포 (Ansible role: docker-compose)
<!-- 이 덩어리 = Claude Code 작업 지시 1회 단위 -->
<!-- Console VM에 7개 컴포넌트 통합 배포 -->

- [x] B-1: roles/secloudit-console/ 디렉토리 구조 생성
  - 파일: `roles/secloudit-console/`
  - 변경: tasks/, templates/, defaults/, handlers/ 생성

- [x] B-2: roles/secloudit-console/tasks/main.yaml 작성
  - 파일: `roles/secloudit-console/tasks/main.yaml`
  - 변경: docker 설치 확인 → compose 배포 → 컨테이너 구동
  ```yaml
  # 1. Docker 설치 확인
  # 2. compose 디렉토리 생성
  # 3. docker-compose.yaml 템플릿 배포
  # 4. 컨테이너 존재 여부 확인 (idempotency)
  # 5. docker-compose up -d 실행
  # 6. MySQL healthcheck 대기
  # 7. MongoDB healthcheck 대기
  ```

- [x] B-3: roles/secloudit-console/templates/docker-compose.yaml.j2 작성
  - 파일: `roles/secloudit-console/templates/docker-compose.yaml.j2`
  - 변경: 7개 컴포넌트 정의 (depends_on으로 순서 보장)
  ```yaml
  # 컨테이너 구동 순서 (depends_on)
  # MySQL (3306)
  # → MongoDB (27017)
  # → FluentD Forward (24224)
  # → GitLab (8080/8443/8022)
  # → ChartMuseum (5080)
  # → gitlabci-module (8093/9091)
  # → secloudit-console (9080)
  ```

- [x] B-4: roles/secloudit-console/defaults/main.yaml 작성
  - 파일: `roles/secloudit-console/defaults/main.yaml`
  - 변경: 기본 변수값 정의 (compose 디렉토리 경로 등)

- [x] B-5: roles/secloudit-console/handlers/main.yaml 작성
  - 파일: `roles/secloudit-console/handlers/main.yaml`
  - 변경: docker-compose restart 핸들러

- [x] B-6: playbooks/deploy-secloudit.yaml — 덩어리 B 범위 추가
  - 파일: `playbooks/deploy-secloudit.yaml`
  - 변경: Console VM 배포 play 추가
  ```yaml
  - name: Console VM 배포
    hosts: console-vm
    become: true
    roles:
      - secloudit-console
  ```

### 덩어리 C: in-cluster 배포 (kubectl apply)
<!-- 이 덩어리 = Claude Code 작업 지시 1회 단위 -->

- [x] C-1: roles/fluentd-agent/ 구조 및 tasks/main.yaml 작성
  - 파일: `roles/fluentd-agent/`
  - 변경: v1.5 기반으로 작성, FLUENT_FORWARD_HOST 변수 확인

- [x] C-2: roles/fluentd-agent/templates/fluentd-agent.yaml.j2 작성
  - 파일: `roles/fluentd-agent/templates/fluentd-agent.yaml.j2`
  - 변경: DaemonSet manifest

- [x] C-3: roles/fluentd-agent/defaults/main.yaml 작성
  - 파일: `roles/fluentd-agent/defaults/main.yaml`
  - 변경: 기본 변수값 정의

- [x] C-4: roles/argocd/ 구조 및 tasks/main.yaml 작성
  - 파일: `roles/argocd/`
  - 변경: ArgoCD 설치 manifest 배포
  ```yaml
  # 1. kubeconfig 경로 확인
  # 2. argocd namespace 생성
  # 3. ArgoCD manifest 배포
  # 4. 배포 완료 대기
  ```

- [x] C-5: roles/argocd/files/ manifest 파일 배치
  - 파일: `roles/argocd/files/`
  - 변경: argocd-install.yaml 배치
  - 참고: # TODO: ArgoCD 버전 확인 필요

- [x] C-6: roles/argocd/defaults/main.yaml 작성
  - 파일: `roles/argocd/defaults/main.yaml`
  - 변경: 기본 변수값 정의

- [x] C-7: roles/tekton/ 구조 및 tasks/main.yaml 작성
  - 파일: `roles/tekton/`
  - 변경: v1.5 기반, 버전 0.44.0/0.22.0으로 업그레이드

- [x] C-8: roles/tekton/files/ manifest 파일 배치
  - 파일: `roles/tekton/files/`
  - 변경: tekton-pipelines-v0.44.0.yaml, tekton-triggers-v0.22.0.yaml 배치
  - 참고: # TODO: 이미지 주소 치환 필요

- [x] C-9: roles/tekton/defaults/main.yaml 작성
  - 파일: `roles/tekton/defaults/main.yaml`
  - 변경: 기본 변수값 정의

- [x] C-10: roles/istio/ 구조 및 tasks/main.yaml 작성
  - 파일: `roles/istio/`
  - 변경: Istio 설치 manifest 배포
  ```yaml
  # 1. kubeconfig 경로 확인
  # 2. istio-system namespace 생성
  # 3. Istio manifest 배포
  # 4. 배포 완료 대기
  ```

- [x] C-11: roles/istio/files/ manifest 파일 배치
  - 파일: `roles/istio/files/`
  - 변경: istio-install.yaml 배치
  - 참고: # TODO: Istio 버전 확인 필요

- [x] C-12: roles/istio/defaults/main.yaml 작성
  - 파일: `roles/istio/defaults/main.yaml`
  - 변경: 기본 변수값 정의

- [x] C-13: playbooks/deploy-secloudit.yaml — 덩어리 C 범위 추가
  - 파일: `playbooks/deploy-secloudit.yaml`
  - 변경: in-cluster 배포 plays 추가 (설치 순서: FluentD → ArgoCD → Tekton → Istio)
  ```yaml
  - name: FluentD Agent 배포
    hosts: k8s-master
    roles:
      - fluentd-agent

  - name: ArgoCD 배포
    hosts: k8s-master
    roles:
      - argocd

  - name: Tekton 배포
    hosts: k8s-master
    roles:
      - tekton

  - name: Istio 배포
    hosts: k8s-master
    roles:
      - istio
  ```

### 덩어리 D: 문서화 및 마무리
<!-- 이 덩어리 = Claude Code 작업 지시 1회 단위 -->

- [x] D-1: README.md 작성
  - 파일: `README.md`
  - 변경: 사용법, 변수 목록, 실행 순서, 사전 조건, v1.5 대비 변경사항

---

## 4. 미결 사항

| 항목 | 관련 덩어리 | 상태 |
|---|---|---|
| Console VM 실제 IP | A | # TODO |
| k8s-master IP (Terraform output) | A | # TODO |
| FluentD FLUENT_FORWARD_HOST 값 | A, C | # TODO |
| FluentD CLUSTER_DIVIDE_VALUE | A, C | # TODO |
| ArgoCD 버전 | C | # TODO |
| Istio 버전 | C | # TODO |
| Nginx Ingress 버전 | - | # TODO (Phase 2) |
| Prometheus 버전 | - | # TODO (Phase 2) |
| gitlabci-module JWT secret 등 상세 설정 | B | # TODO |
| Tekton manifest 이미지 주소 치환 | C | # TODO |

---

## 5. 인라인 메모란

<!--
  사람이 검토하면서 메모를 남기는 공간입니다.
  Claude는 3단계에서 이 메모를 반영하여 plan.md를 업데이트합니다.

  예시:
  [메모] A-2: Console VM과 LB VM 분리 여부 확인
  [메모] B-3: GitLab 볼륨 마운트 경로 확인
  [질문] C-5: ArgoCD HA 구성 필요?
-->

**반영 완료된 메모:**
- (없음)

---

## 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-03-16 | 초안 작성 — 4개 덩어리 (A: VM 환경 준비, B: Console VM 배포, C: in-cluster 배포, D: 문서화) |
| 2026-03-16 | 구현 완료 — 26개 항목 모두 완료, 상태 `완료`로 변경 |
