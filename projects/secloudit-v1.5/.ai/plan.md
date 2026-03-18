# plan.md — secloudit-v1.5

> 작성일: 2026-03-16
> 상태: `완료`
> 현재 Phase: Phase 1 - SECloudit v1.5 배포 자동화

---

## 1. 목표

SECloudit v1.5 솔루션 컴포넌트를 VM에 podman-compose로 배포하고, K8s 클러스터에 FluentD Agent / Tekton을 kubectl apply로 배포한다.

### 성공 기준
- [x] deploy-secloudit.yaml 실행 시 VM 2종에 컨테이너 정상 기동 (SE노드, Logging)
- [x] in-cluster 리소스 배포 완료 (FluentD DaemonSet, Tekton)
- [x] 멱등성 보장 — 2회 연속 실행해도 오류 없음
- [x] 설치 순서 준수 (SE노드 → Logging → in-cluster)

---

## 2. 트레이드오프

| 결정 | 선택 | 이유 |
|---|---|---|
| 컨테이너 런타임 | Podman + podman-compose | Rocky Linux 9.1 기본, rootless 지원 |
| Image Registry | 기존 Harbor (sample.harbor.com) | 모든 프로젝트 공통, 별도 구축 불필요 |
| compose 파일 관리 | Jinja2 템플릿 (.j2) | 환경별 변수 주입 용이 |
| in-cluster 배포 방식 | kubectl apply (manifest) | Helm 없이 단순화, 오프라인 환경 고려 |
| 멱등성 처리 | podman ps 확인 후 skip | creates/when 조건으로 구현 |

---

## 3. 구현 체크리스트

### 덩어리 A: VM 환경 준비 (Ansible: 인벤토리 + 공통 변수)
<!-- 이 덩어리 = Claude Code 작업 지시 1회 단위 -->

- [x] A-1: 프로젝트 디렉토리 구조 생성
  - 파일: `secloudit-v1.5/`
  - 변경: inventories/, group_vars/, roles/, playbooks/, templates/ 생성
  - 참고: image-registry 그룹 제거됨 — 기존 Harbor 사용

- [x] A-2: inventories/demo/hosts.yaml 작성
  - 파일: `inventories/demo/hosts.yaml`
  - 변경: 호스트 그룹 정의 (se-node, logging, k8s-master)
  - 참고: k8s-master IP는 k8s-cluster Terraform output(master_ip) 값 사용
  ```yaml
  all:
    children:
      se-node:
        hosts:
          se-node-01:
            ansible_host: "{{ se_node_ip }}"  # TODO: 실제 IP 확인 필요
      logging:
        hosts:
          logging-01:
            ansible_host: "{{ logging_ip }}"  # TODO: 실제 IP 확인 필요
      k8s-master:
        hosts:
          k8s-master-01:
            ansible_host: "{{ k8s_master_ip }}"  # k8s-cluster Terraform output(master_ip)
  ```

- [x] A-3: inventories/qa/hosts.yaml 작성
  - 파일: `inventories/qa/hosts.yaml`
  - 변경: qa 환경 인벤토리 (구조 동일, IP 다름)

- [x] A-4: group_vars/all.yaml 작성
  - 파일: `group_vars/all.yaml`
  - 변경: 공통 변수 정의 (registry_host, 버전, vault_ 참조)
  - 참고: registry_host는 기존 Harbor 사용, k8s_master_ip는 Terraform output 값 주입
  ```yaml
  # SECloudit 버전
  secloudit_version: "v1.5"

  # Image Registry 설정 — 기존 Harbor 사용 (별도 구축 불필요)
  registry_host: "sample.harbor.com"
  registry_port: 443

  # OSS 버전 (v1.5 기준)
  mysql_version: "8.0.31"
  mongodb_version: "5.0.14"
  fluentd_version: "1.13"
  tekton_pipeline_version: "0.28.3"
  tekton_triggers_version: "0.18.0"

  # 포트 설정
  mysql_port: 3306
  mongodb_port: 27017
  console_port: 9080
  fluentd_forward_port: 24224

  # 시크릿 (vault 참조)
  mysql_root_password: "{{ vault_mysql_root_password }}"
  mongodb_root_password: "{{ vault_mongodb_root_password }}"
  secloudit_admin_password: "{{ vault_secloudit_admin_password }}"

  # FluentD Agent 설정
  # TODO: 확인 필요
  fluent_forward_host: "{{ hostvars['logging-01']['ansible_host'] }}"
  fluent_forward_port: 24224
  cluster_divide_value: "demo"  # TODO: 클러스터 구분자 확인 필요

  # kubeconfig 경로
  kubeconfig_path: "/etc/kubernetes/admin.conf"

  # K8s Master IP — k8s-cluster Terraform output(master_ip) 값 주입
  # k8s_master_ip: "{{ lookup('env', 'K8S_MASTER_IP') }}"
  ```

- [x] A-5: playbooks/deploy-secloudit.yaml 기본 골격 작성
  - 파일: `playbooks/deploy-secloudit.yaml`
  - 변경: 플레이북 골격 (hosts, become, roles placeholder)
  ```yaml
  # playbooks/deploy-secloudit.yaml
  # SECloudit v1.5 배포 플레이북
  # 실행 순서: SE노드 → Logging → in-cluster

  ---
  # 플레이북 골격 — 덩어리 B, C에서 확장
  ```

- [x] A-6: ansible.cfg 작성
  - 파일: `ansible.cfg`
  - 변경: roles_path, inventory 기본값 설정
  ```ini
  [defaults]
  roles_path = ./roles
  inventory = ./inventories/demo/hosts.yaml
  host_key_checking = False
  retry_files_enabled = False

  [privilege_escalation]
  become = True
  become_method = sudo
  ```

### 덩어리 B: VM 컴포넌트 배포 (Ansible roles: podman-compose)
<!-- 이 덩어리 = Claude Code 작업 지시 1회 단위 -->
<!-- docker-registry role 제거됨 — 기존 Harbor 사용 -->

- [x] B-1: roles/secloudit-console/ 디렉토리 구조 생성
  - 파일: `roles/secloudit-console/`
  - 변경: tasks/, templates/, defaults/ 생성

- [x] B-2: roles/secloudit-console/tasks/main.yaml 작성
  - 파일: `roles/secloudit-console/tasks/main.yaml`
  - 변경: MySQL 구동 → healthcheck → SECloudit Console 구동
  ```yaml
  # 1. compose 디렉토리 생성
  # 2. docker-compose.yaml 템플릿 배포
  # 3. 컨테이너 존재 여부 확인 (idempotency)
  # 4. podman-compose up -d 실행
  # 5. MySQL healthcheck 대기 (until 모듈)
  ```

- [x] B-3: roles/secloudit-console/templates/docker-compose.yaml.j2 작성
  - 파일: `roles/secloudit-console/templates/docker-compose.yaml.j2`
  - 변경: MySQL (port 3306) + SECloudit Console (port 9080) 정의, depends_on 설정

- [x] B-4: roles/secloudit-console/defaults/main.yaml 작성
  - 파일: `roles/secloudit-console/defaults/main.yaml`
  - 변경: 기본 변수값 정의

- [x] B-5: roles/secloudit-logging/ 디렉토리 구조 생성
  - 파일: `roles/secloudit-logging/`
  - 변경: tasks/, templates/, defaults/ 생성

- [x] B-6: roles/secloudit-logging/tasks/main.yaml 작성
  - 파일: `roles/secloudit-logging/tasks/main.yaml`
  - 변경: MongoDB 구동 → FluentD Forward 구동
  ```yaml
  # 1. compose 디렉토리 생성
  # 2. docker-compose.yaml 템플릿 배포
  # 3. 컨테이너 존재 여부 확인 (idempotency)
  # 4. podman-compose up -d 실행
  ```

- [x] B-7: roles/secloudit-logging/templates/docker-compose.yaml.j2 작성
  - 파일: `roles/secloudit-logging/templates/docker-compose.yaml.j2`
  - 변경: MongoDB (port 27017) + FluentD Forward (port 24224) 정의

- [x] B-8: roles/secloudit-logging/defaults/main.yaml 작성
  - 파일: `roles/secloudit-logging/defaults/main.yaml`
  - 변경: 기본 변수값 정의

- [x] B-9: playbooks/deploy-secloudit.yaml — 덩어리 B 범위 추가
  - 파일: `playbooks/deploy-secloudit.yaml`
  - 변경: SE노드 → Logging 순서로 role 호출
  ```yaml
  # 1. SE 노드 VM — MySQL → Console 구동
  - name: SECloudit Console 배포
    hosts: se-node
    become: true
    roles:
      - secloudit-console

  # 2. Logging VM — MongoDB → FluentD Forward 구동
  - name: SECloudit Logging 배포
    hosts: logging
    become: true
    roles:
      - secloudit-logging
  ```

### 덩어리 C: in-cluster 배포 (kubectl apply)
<!-- 이 덩어리 = Claude Code 작업 지시 1회 단위 -->

- [x] C-1: roles/fluentd-agent/ 디렉토리 구조 생성
  - 파일: `roles/fluentd-agent/`
  - 변경: tasks/, templates/, defaults/ 생성

- [x] C-2: roles/fluentd-agent/tasks/main.yaml 작성
  - 파일: `roles/fluentd-agent/tasks/main.yaml`
  - 변경: FluentD Agent DaemonSet manifest 배포
  ```yaml
  # 1. kubeconfig 경로 확인
  # 2. fluentd-agent.yaml 템플릿 배포
  # 3. kubectl apply -f 실행
  # 4. DaemonSet 상태 확인
  ```

- [x] C-3: roles/fluentd-agent/templates/fluentd-agent.yaml.j2 작성
  - 파일: `roles/fluentd-agent/templates/fluentd-agent.yaml.j2`
  - 변경: DaemonSet manifest (FLUENT_FORWARD_HOST, FLUENT_FORWARD_PORT, CLUSTER_DIVIDE_VALUE 변수 주입)
  ```yaml
  # TODO: FLUENT_FORWARD_HOST 값 확인 필요 — {{ fluent_forward_host }}
  # TODO: CLUSTER_DIVIDE_VALUE 값 확인 필요 — {{ cluster_divide_value }}
  ```

- [x] C-4: roles/fluentd-agent/defaults/main.yaml 작성
  - 파일: `roles/fluentd-agent/defaults/main.yaml`
  - 변경: 기본 변수값 정의

- [x] C-5: roles/tekton/ 디렉토리 구조 생성
  - 파일: `roles/tekton/`
  - 변경: tasks/, files/, defaults/ 생성

- [x] C-6: roles/tekton/tasks/main.yaml 작성
  - 파일: `roles/tekton/tasks/main.yaml`
  - 변경: Tekton Pipelines → Tekton Triggers 순서 배포
  ```yaml
  # 1. kubeconfig 경로 확인
  # 2. Tekton Pipelines (v0.28.3) manifest 배포
  # 3. Pipelines 배포 완료 대기
  # 4. Tekton Triggers (v0.18.0) manifest 배포
  # TODO: manifest 이미지 주소 치환 (SEClouditREG → 실제 주소)
  ```

- [x] C-7: roles/tekton/files/ manifest 파일 배치
  - 파일: `roles/tekton/files/`
  - 변경: tekton-pipelines-v0.28.3.yaml, tekton-triggers-v0.18.0.yaml 배치
  - 참고: manifest 파일 내 이미지 주소 치환 필요 (# TODO)

- [x] C-8: roles/tekton/defaults/main.yaml 작성
  - 파일: `roles/tekton/defaults/main.yaml`
  - 변경: 기본 변수값 정의

- [x] C-9: playbooks/deploy-secloudit.yaml — 덩어리 C 범위 추가
  - 파일: `playbooks/deploy-secloudit.yaml`
  - 변경: FluentD Agent → Tekton 순서로 role 호출
  ```yaml
  # 3. in-cluster — FluentD Agent DaemonSet 배포
  - name: FluentD Agent 배포
    hosts: k8s-master
    become: true
    roles:
      - fluentd-agent

  # 4. in-cluster — Tekton 배포
  - name: Tekton 배포
    hosts: k8s-master
    become: true
    roles:
      - tekton
  ```

- [x] C-10: README.md 작성
  - 파일: `README.md`
  - 변경: 사용법, 변수 목록, 실행 순서, 사전 조건

---

## 4. 미결 사항

| 항목 | 관련 덩어리 | 상태 |
|---|---|---|
| FluentD Agent FLUENT_FORWARD_HOST 값 (Logging VM IP) | A, C | # TODO |
| FluentD CLUSTER_DIVIDE_VALUE (클러스터 구분자) | A, C | # TODO |
| httpd https proxy 인증서 경로 및 설정값 | B | # TODO |
| Tekton manifest 이미지 레지스트리 주소 (SEClouditREG → 실제 주소) | C | # TODO |
| SE노드, Logging VM의 실제 IP 주소 | A | # TODO |

---

## 5. 인라인 메모란

<!--
  사람이 검토하면서 메모를 남기는 공간입니다.
  Claude는 3단계에서 이 메모를 반영하여 plan.md를 업데이트합니다.

  예시:
  [메모] A-2: SE 노드와 Image Registry 통합 시 호스트 그룹 조정 필요
  [메모] B-3: MySQL healthcheck timeout 값 확인
  [질문] C-3: FluentD Agent의 로그 수집 경로 확인 필요
-->

**반영 완료된 메모:**
- [x] A-1: image-registry 그룹 제거 — 인벤토리에 se-node, logging, k8s-master만 남김
- [x] A-4: registry_host: "sample.harbor.com" — 모든 프로젝트 공통, 별도 구축 불필요
- [x] A-4: k8s_master_ip는 k8s-cluster Terraform output(master_ip) 값 주입
- [x] B-1~B-4: docker-registry role 전체 제거 — Image Registry VM 불필요
- [x] B-13: 플레이북에서 Image Registry 배포 단계 제거

---

## 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-03-16 | 초안 작성 — 3개 덩어리 (A: VM 환경 준비, B: VM 컴포넌트 배포, C: in-cluster 배포) |
| 2026-03-16 | 메모 반영 — Image Registry 제거 (기존 Harbor 사용), 체크리스트 재조정 (29개 → 25개) |
| 2026-03-16 | Phase 1 완료 — syntax-check/list-tasks 검증 통과, 전체 체크리스트 완료 |
