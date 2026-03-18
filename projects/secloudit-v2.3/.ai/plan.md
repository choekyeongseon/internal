# plan.md — secloudit-v2.3

> 작성일: 2026-03-16
> 상태: `검토 중`
> 현재 Phase: Phase 1 - 전체 구조 구현

---

## 1. 목표

SECloudit v2.3 배포 자동화를 위한 Ansible 프로젝트 구현 (VM 4종 docker-compose + in-cluster kubectl apply)

### 성공 기준
- [x] 모든 inventories, group_vars, playbooks 파일 생성됨
- [x] 8개 roles 디렉토리 구조 및 tasks/templates 완성됨
- [x] ansible-playbook --syntax-check 통과
- [x] 미확인 항목은 # TODO로 표시됨 (임의 결정 없음)

---

## 2. 트레이드오프

| 결정 | 선택 | 이유 |
|---|---|---|
| docker-compose 관리 | Jinja2 템플릿 (.j2) | 환경별 변수 치환 가능, 멱등성 확보 |
| 컨테이너 존재 확인 | docker ps + when 조건 | Ansible 멱등성 패턴, 불필요한 재시작 방지 |
| 시크릿 관리 | vault_ prefix 변수 | Ansible Vault 통합, 평문 노출 방지 |
| in-cluster 배포 | delegate_to: k8s-master | kubeconfig 경로 확인 후 kubectl apply |
| Role 구조 | 컴포넌트별 분리 | 독립 배포 가능, 유지보수 용이 |

---

## 3. 구현 체크리스트

### 덩어리 A: 프로젝트 기본 구조
<!-- 이 덩어리 = Claude Code 작업 지시 1회 단위 -->

- [x] A-1: inventories/demo/hosts.yaml 생성
  - 파일: `inventories/demo/hosts.yaml`
  - 변경: 5개 호스트 그룹 정의 (innogrid_auth, console_vm, logging_vm, util_vm, k8s_master)
  ```yaml
  all:
    children:
      innogrid_auth:
        hosts:
          innogrid-auth-vm:
            ansible_host: "{{ vault_innogrid_auth_ip }}"  # TODO: 실제 IP 확인
      console_vm:
        hosts:
          console-vm:
            ansible_host: "{{ vault_console_vm_ip }}"  # TODO: 실제 IP 확인
      logging_vm:
        hosts:
          logging-vm:
            ansible_host: "{{ vault_logging_vm_ip }}"  # TODO: 실제 IP 확인
      util_vm:
        hosts:
          util-vm:
            ansible_host: "{{ vault_util_vm_ip }}"  # TODO: 실제 IP 확인
      k8s_master:
        hosts:
          k8s-master:
            ansible_host: "{{ vault_k8s_master_ip }}"  # TODO: Terraform output
  ```

- [x] A-2: inventories/qa/hosts.yaml 생성
  - 파일: `inventories/qa/hosts.yaml`
  - 변경: demo와 동일 구조, QA 환경용 변수 참조

- [x] A-3: group_vars/all.yaml 생성
  - 파일: `group_vars/all.yaml`
  - 변경: 공통 변수 정의
  ```yaml
  ---
  # 이미지 레지스트리
  image_registry: sample.harbor.com

  # 포트 설정
  keycloak_port: 8012
  portal_port: 8010
  admin_portal_port: 8011
  mongodb_port: 27017
  fluentd_port: 24224
  chartmuseum_port: 5080
  mysql_port: 3306

  # 공통 설정
  docker_compose_dir: /opt/secloudit
  kubeconfig_path: /root/.kube/config  # TODO: 확인 필요

  # 시크릿 참조 (값은 vault에서 관리)
  # vault_keycloak_admin_password
  # vault_keycloak_db_password
  # vault_mysql_root_password
  # vault_mongodb_root_password
  # vault_secloudit_admin_password
  # vault_chartmuseum_password
  ```

- [x] A-4: playbooks/deploy-secloudit.yaml 생성
  - 파일: `playbooks/deploy-secloudit.yaml`
  - 변경: 메인 플레이북 (8단계 설치 순서 준수)
  ```yaml
  ---
  # SECloudit v2.3 배포 플레이북
  # 설치 순서 (변경 금지):
  # 1. innogrid-auth VM
  # 2. Console VM
  # 3. Logging VM
  # 4. Util VM
  # 5-8. in-cluster 배포

  - name: "1. Deploy innogrid-auth VM (Keycloak + MySQL)"
    hosts: innogrid_auth
    become: true
    roles:
      - innogrid-auth

  - name: "2. Deploy Console VM components"
    hosts: console_vm
    become: true
    roles:
      - secloudit-console

  - name: "3. Deploy Logging VM (MongoDB + FluentD Forwarder)"
    hosts: logging_vm
    become: true
    roles:
      - secloudit-logging

  - name: "4. Deploy Util VM (ChartMuseum + CoreDNS + DNS Agent)"
    hosts: util_vm
    become: true
    roles:
      - secloudit-util

  - name: "5. Deploy FluentD Agent DaemonSet"
    hosts: k8s_master
    become: true
    roles:
      - fluentd-agent

  - name: "6. Deploy Tekton (package only)"
    hosts: k8s_master
    become: true
    roles:
      - tekton

  - name: "7. Deploy Kafka"
    hosts: k8s_master
    become: true
    roles:
      - kafka

  - name: "8. Deploy Alert Module"
    hosts: k8s_master
    become: true
    roles:
      - alert-module
  ```

---

### 덩어리 B: VM 배포 Roles (innogrid-auth, secloudit-console, secloudit-logging, secloudit-util)
<!-- 이 덩어리 = Claude Code 작업 지시 1회 단위 -->

- [x] B-1: roles/innogrid-auth 구조 생성
  - 파일: `roles/innogrid-auth/tasks/main.yaml`
  - 변경: Keycloak + MySQL 배포 태스크
  ```yaml
  ---
  - name: Ensure docker-compose directory exists
    ansible.builtin.file:
      path: "{{ docker_compose_dir }}/innogrid-auth"
      state: directory
      mode: '0755'

  - name: Check if Keycloak container is running
    ansible.builtin.shell: docker ps --filter "name=keycloak" --format "{{ '{{' }}.Names{{ '}}' }}"
    register: keycloak_container
    changed_when: false

  - name: Template docker-compose.yaml
    ansible.builtin.template:
      src: docker-compose.yaml.j2
      dest: "{{ docker_compose_dir }}/innogrid-auth/docker-compose.yaml"
      mode: '0644'

  - name: Start Keycloak + MySQL containers
    ansible.builtin.shell: docker-compose up -d
    args:
      chdir: "{{ docker_compose_dir }}/innogrid-auth"
    when: keycloak_container.stdout == ""
  ```

- [x] B-2: roles/innogrid-auth/templates/docker-compose.yaml.j2 생성
  - 파일: `roles/innogrid-auth/templates/docker-compose.yaml.j2`
  - 변경: Keycloak + MySQL docker-compose 템플릿
  ```yaml
  version: '3.8'
  services:
    mysql-keycloak:
      image: {{ image_registry }}/mysql:latest  # TODO: 버전 확인
      container_name: mysql-keycloak
      environment:
        MYSQL_ROOT_PASSWORD: {{ vault_keycloak_db_password }}
        MYSQL_DATABASE: keycloak
      ports:
        - "{{ mysql_port }}:3306"
      volumes:
        - mysql-keycloak-data:/var/lib/mysql
      restart: unless-stopped

    keycloak:
      image: {{ image_registry }}/keycloak:latest  # TODO: 버전 확인
      container_name: keycloak
      environment:
        KEYCLOAK_ADMIN: admin
        KEYCLOAK_ADMIN_PASSWORD: {{ vault_keycloak_admin_password }}
        KC_DB: mysql
        KC_DB_URL: jdbc:mysql://mysql-keycloak:3306/keycloak
        KC_DB_USERNAME: root
        KC_DB_PASSWORD: {{ vault_keycloak_db_password }}
        # TODO: realm/client 초기 설정값 확인 필요
      ports:
        - "{{ keycloak_port }}:8080"
      depends_on:
        - mysql-keycloak
      restart: unless-stopped

  volumes:
    mysql-keycloak-data:
  ```

- [x] B-3: roles/innogrid-auth/defaults/main.yaml 생성
  - 파일: `roles/innogrid-auth/defaults/main.yaml`
  - 변경: role 기본 변수 정의
  ```yaml
  ---
  # innogrid-auth role defaults
  innogrid_auth_compose_dir: "{{ docker_compose_dir }}/innogrid-auth"
  ```

- [x] B-4: roles/secloudit-console 구조 생성
  - 파일: `roles/secloudit-console/tasks/main.yaml`
  - 변경: Console VM 컴포넌트 배포 (gateway → jxgo → java-api → k8s-go → portal → admin-portal → MySQL → gitlab-runner 순서)
  ```yaml
  ---
  - name: Ensure docker-compose directory exists
    ansible.builtin.file:
      path: "{{ docker_compose_dir }}/secloudit-console"
      state: directory
      mode: '0755'

  - name: Check if portal container is running
    ansible.builtin.shell: docker ps --filter "name=portal" --format "{{ '{{' }}.Names{{ '}}' }}"
    register: portal_container
    changed_when: false

  - name: Template docker-compose.yaml
    ansible.builtin.template:
      src: docker-compose.yaml.j2
      dest: "{{ docker_compose_dir }}/secloudit-console/docker-compose.yaml"
      mode: '0644'

  - name: Start Console VM containers
    ansible.builtin.shell: docker-compose up -d
    args:
      chdir: "{{ docker_compose_dir }}/secloudit-console"
    when: portal_container.stdout == ""
  ```

- [x] B-5: roles/secloudit-console/templates/docker-compose.yaml.j2 생성
  - 파일: `roles/secloudit-console/templates/docker-compose.yaml.j2`
  - 변경: Console VM 8개 컴포넌트 docker-compose 템플릿
  ```yaml
  version: '3.8'
  services:
    gateway:
      image: {{ image_registry }}/secloudit/gateway:latest  # TODO: 버전 확인
      container_name: gateway
      restart: unless-stopped
      # TODO: 포트/환경변수 확인 필요

    jxgo:
      image: {{ image_registry }}/secloudit/jxgo:latest  # TODO: 버전 확인
      container_name: jxgo
      depends_on:
        - gateway
      restart: unless-stopped

    java-api:
      image: {{ image_registry }}/secloudit/java-api:latest  # TODO: 버전 확인
      container_name: java-api
      depends_on:
        - jxgo
      restart: unless-stopped

    k8s-go:
      image: {{ image_registry }}/secloudit/k8s-go:latest  # TODO: 버전 확인
      container_name: k8s-go
      depends_on:
        - java-api
      restart: unless-stopped

    portal:
      image: {{ image_registry }}/secloudit/portal:latest  # TODO: 버전 확인
      container_name: portal
      ports:
        - "{{ portal_port }}:8080"
      depends_on:
        - k8s-go
      restart: unless-stopped

    admin-portal:
      image: {{ image_registry }}/secloudit/admin-portal:latest  # TODO: 버전 확인
      container_name: admin-portal
      ports:
        - "{{ admin_portal_port }}:8080"
      depends_on:
        - portal
      restart: unless-stopped

    mysql:
      image: {{ image_registry }}/mysql:latest  # TODO: 버전 확인
      container_name: mysql-console
      environment:
        MYSQL_ROOT_PASSWORD: {{ vault_mysql_root_password }}
      ports:
        - "{{ mysql_port }}:3306"
      volumes:
        - mysql-console-data:/var/lib/mysql
      restart: unless-stopped

    gitlab-runner:
      image: {{ image_registry }}/gitlab/gitlab-runner:latest  # TODO: 버전 확인
      container_name: gitlab-runner
      volumes:
        - /var/run/docker.sock:/var/run/docker.sock
        - gitlab-runner-config:/etc/gitlab-runner
      restart: unless-stopped

  volumes:
    mysql-console-data:
    gitlab-runner-config:
  ```

- [x] B-6: roles/secloudit-console/defaults/main.yaml 생성
  - 파일: `roles/secloudit-console/defaults/main.yaml`
  - 변경: role 기본 변수 정의

- [x] B-7: roles/secloudit-logging 구조 생성
  - 파일: `roles/secloudit-logging/tasks/main.yaml`
  - 변경: MongoDB + FluentD Forwarder 배포 태스크
  ```yaml
  ---
  - name: Ensure docker-compose directory exists
    ansible.builtin.file:
      path: "{{ docker_compose_dir }}/secloudit-logging"
      state: directory
      mode: '0755'

  - name: Check if MongoDB container is running
    ansible.builtin.shell: docker ps --filter "name=mongodb" --format "{{ '{{' }}.Names{{ '}}' }}"
    register: mongodb_container
    changed_when: false

  - name: Template docker-compose.yaml
    ansible.builtin.template:
      src: docker-compose.yaml.j2
      dest: "{{ docker_compose_dir }}/secloudit-logging/docker-compose.yaml"
      mode: '0644'

  - name: Start MongoDB + FluentD containers
    ansible.builtin.shell: docker-compose up -d
    args:
      chdir: "{{ docker_compose_dir }}/secloudit-logging"
    when: mongodb_container.stdout == ""
  ```

- [x] B-8: roles/secloudit-logging/templates/docker-compose.yaml.j2 생성
  - 파일: `roles/secloudit-logging/templates/docker-compose.yaml.j2`
  - 변경: MongoDB + FluentD Forwarder docker-compose 템플릿
  ```yaml
  version: '3.8'
  services:
    mongodb:
      image: {{ image_registry }}/mongo:latest  # TODO: 버전 확인
      container_name: mongodb
      environment:
        MONGO_INITDB_ROOT_USERNAME: root
        MONGO_INITDB_ROOT_PASSWORD: {{ vault_mongodb_root_password }}
      ports:
        - "{{ mongodb_port }}:27017"
      volumes:
        - mongodb-data:/data/db
      restart: unless-stopped

    fluentd-forwarder:
      image: {{ image_registry }}/fluent/fluentd:latest  # TODO: 버전 확인
      container_name: fluentd-forwarder
      ports:
        - "{{ fluentd_port }}:24224"
      environment:
        FLUENT_FORWARD_HOST: "{{ vault_fluentd_forward_host }}"  # TODO: 확인 필요
        CLUSTER_DIVIDE_VALUE: "{{ vault_cluster_divide_value }}"  # TODO: 확인 필요
      volumes:
        - fluentd-config:/fluentd/etc
      depends_on:
        - mongodb
      restart: unless-stopped

  volumes:
    mongodb-data:
    fluentd-config:
  ```

- [x] B-9: roles/secloudit-logging/defaults/main.yaml 생성
  - 파일: `roles/secloudit-logging/defaults/main.yaml`
  - 변경: role 기본 변수 정의

- [x] B-10: roles/secloudit-util 구조 생성
  - 파일: `roles/secloudit-util/tasks/main.yaml`
  - 변경: ChartMuseum + CoreDNS + DNS Agent 배포 태스크
  ```yaml
  ---
  - name: Ensure docker-compose directory exists
    ansible.builtin.file:
      path: "{{ docker_compose_dir }}/secloudit-util"
      state: directory
      mode: '0755'

  - name: Check if ChartMuseum container is running
    ansible.builtin.shell: docker ps --filter "name=chartmuseum" --format "{{ '{{' }}.Names{{ '}}' }}"
    register: chartmuseum_container
    changed_when: false

  - name: Template docker-compose.yaml
    ansible.builtin.template:
      src: docker-compose.yaml.j2
      dest: "{{ docker_compose_dir }}/secloudit-util/docker-compose.yaml"
      mode: '0644'

  - name: Start Util VM containers
    ansible.builtin.shell: docker-compose up -d
    args:
      chdir: "{{ docker_compose_dir }}/secloudit-util"
    when: chartmuseum_container.stdout == ""
  ```

- [x] B-11: roles/secloudit-util/templates/docker-compose.yaml.j2 생성
  - 파일: `roles/secloudit-util/templates/docker-compose.yaml.j2`
  - 변경: ChartMuseum + CoreDNS + DNS Agent docker-compose 템플릿
  ```yaml
  version: '3.8'
  services:
    chartmuseum:
      image: {{ image_registry }}/chartmuseum/chartmuseum:latest  # TODO: 버전 확인
      container_name: chartmuseum
      environment:
        BASIC_AUTH_USER: admin
        BASIC_AUTH_PASS: {{ vault_chartmuseum_password }}
        STORAGE: local
        STORAGE_LOCAL_ROOTDIR: /charts
      ports:
        - "{{ chartmuseum_port }}:8080"
      volumes:
        - chartmuseum-data:/charts
      restart: unless-stopped

    coredns:
      image: {{ image_registry }}/coredns/coredns:latest  # TODO: 버전 확인
      container_name: coredns
      # TODO: CoreDNS 설정값 확인 필요
      volumes:
        - coredns-config:/etc/coredns
      restart: unless-stopped

    dns-agent:
      image: {{ image_registry }}/secloudit/dns-agent:latest  # TODO: 버전 확인
      container_name: dns-agent
      # TODO: DNS Agent 설정값 확인 필요
      depends_on:
        - coredns
      restart: unless-stopped

  volumes:
    chartmuseum-data:
    coredns-config:
  ```

- [x] B-12: roles/secloudit-util/defaults/main.yaml 생성
  - 파일: `roles/secloudit-util/defaults/main.yaml`
  - 변경: role 기본 변수 정의

---

### 덩어리 C: in-cluster Roles (fluentd-agent, tekton, kafka, alert-module)
<!-- 이 덩어리 = Claude Code 작업 지시 1회 단위 -->

- [x] C-1: roles/fluentd-agent 구조 생성
  - 파일: `roles/fluentd-agent/tasks/main.yaml`
  - 변경: FluentD Agent DaemonSet 배포
  ```yaml
  ---
  - name: Ensure kubeconfig exists
    ansible.builtin.stat:
      path: "{{ kubeconfig_path }}"
    register: kubeconfig_stat
    failed_when: not kubeconfig_stat.stat.exists

  - name: Template FluentD DaemonSet manifest
    ansible.builtin.template:
      src: fluentd-daemonset.yaml.j2
      dest: /tmp/fluentd-daemonset.yaml
      mode: '0644'

  - name: Apply FluentD DaemonSet
    ansible.builtin.shell: kubectl apply -f /tmp/fluentd-daemonset.yaml
    environment:
      KUBECONFIG: "{{ kubeconfig_path }}"
  ```

- [x] C-2: roles/fluentd-agent/templates/fluentd-daemonset.yaml.j2 생성
  - 파일: `roles/fluentd-agent/templates/fluentd-daemonset.yaml.j2`
  - 변경: FluentD DaemonSet K8s manifest 템플릿
  ```yaml
  apiVersion: apps/v1
  kind: DaemonSet
  metadata:
    name: fluentd-agent
    namespace: kube-system
    labels:
      app: fluentd-agent
  spec:
    selector:
      matchLabels:
        app: fluentd-agent
    template:
      metadata:
        labels:
          app: fluentd-agent
      spec:
        containers:
          - name: fluentd
            image: {{ image_registry }}/fluent/fluentd:latest  # TODO: 버전 확인
            env:
              - name: FLUENT_FORWARD_HOST
                value: "{{ vault_fluentd_forward_host }}"  # TODO: 확인 필요
            volumeMounts:
              - name: varlog
                mountPath: /var/log
              - name: varlibdockercontainers
                mountPath: /var/lib/docker/containers
                readOnly: true
        volumes:
          - name: varlog
            hostPath:
              path: /var/log
          - name: varlibdockercontainers
            hostPath:
              path: /var/lib/docker/containers
  ```

- [x] C-3: roles/fluentd-agent/defaults/main.yaml 생성
  - 파일: `roles/fluentd-agent/defaults/main.yaml`
  - 변경: role 기본 변수 정의

- [x] C-4: roles/tekton 구조 생성
  - 파일: `roles/tekton/tasks/main.yaml`
  - 변경: Tekton 패키지 설치 (메뉴 제거, 패키지만 유지)
  ```yaml
  ---
  - name: Ensure kubeconfig exists
    ansible.builtin.stat:
      path: "{{ kubeconfig_path }}"
    register: kubeconfig_stat
    failed_when: not kubeconfig_stat.stat.exists

  - name: Copy Tekton manifests
    ansible.builtin.template:
      src: "{{ item }}"
      dest: "/tmp/{{ item | basename | regex_replace('.j2$', '') }}"
      mode: '0644'
    loop:
      - tekton-pipelines.yaml.j2

  - name: Apply Tekton manifests
    ansible.builtin.shell: kubectl apply -f /tmp/tekton-pipelines.yaml
    environment:
      KUBECONFIG: "{{ kubeconfig_path }}"
  ```

- [x] C-5: roles/tekton/templates/tekton-pipelines.yaml.j2 생성
  - 파일: `roles/tekton/templates/tekton-pipelines.yaml.j2`
  - 변경: Tekton Pipelines K8s manifest 템플릿
  ```yaml
  # TODO: Tekton 버전 및 manifest 확인 필요
  # 공식 Tekton release manifest를 Harbor에서 가져오도록 구성
  # kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
  ---
  apiVersion: v1
  kind: Namespace
  metadata:
    name: tekton-pipelines
  # TODO: 나머지 Tekton 리소스 추가
  ```

- [x] C-6: roles/tekton/defaults/main.yaml 생성
  - 파일: `roles/tekton/defaults/main.yaml`
  - 변경: role 기본 변수 정의

- [x] C-7: roles/kafka 구조 생성
  - 파일: `roles/kafka/tasks/main.yaml`
  - 변경: Kafka in-cluster 배포 (신규)
  ```yaml
  ---
  - name: Ensure kubeconfig exists
    ansible.builtin.stat:
      path: "{{ kubeconfig_path }}"
    register: kubeconfig_stat
    failed_when: not kubeconfig_stat.stat.exists

  - name: Template Kafka manifests
    ansible.builtin.template:
      src: kafka.yaml.j2
      dest: /tmp/kafka.yaml
      mode: '0644'

  - name: Apply Kafka manifests
    ansible.builtin.shell: kubectl apply -f /tmp/kafka.yaml
    environment:
      KUBECONFIG: "{{ kubeconfig_path }}"
  ```

- [x] C-8: roles/kafka/templates/kafka.yaml.j2 생성
  - 파일: `roles/kafka/templates/kafka.yaml.j2`
  - 변경: Kafka K8s manifest 템플릿
  ```yaml
  # TODO: Kafka 버전 및 설정 확인 필요
  ---
  apiVersion: v1
  kind: Namespace
  metadata:
    name: kafka
  ---
  # TODO: Kafka StatefulSet, Service, ConfigMap 추가
  # Strimzi Kafka Operator 또는 직접 배포 방식 확인 필요
  ```

- [x] C-9: roles/kafka/defaults/main.yaml 생성
  - 파일: `roles/kafka/defaults/main.yaml`
  - 변경: role 기본 변수 정의

- [x] C-10: roles/alert-module 구조 생성
  - 파일: `roles/alert-module/tasks/main.yaml`
  - 변경: Alert Module in-cluster 배포 (신규, Kafka 의존)
  ```yaml
  ---
  - name: Ensure kubeconfig exists
    ansible.builtin.stat:
      path: "{{ kubeconfig_path }}"
    register: kubeconfig_stat
    failed_when: not kubeconfig_stat.stat.exists

  - name: Template Alert Module manifests
    ansible.builtin.template:
      src: alert-module.yaml.j2
      dest: /tmp/alert-module.yaml
      mode: '0644'

  - name: Apply Alert Module manifests
    ansible.builtin.shell: kubectl apply -f /tmp/alert-module.yaml
    environment:
      KUBECONFIG: "{{ kubeconfig_path }}"
  ```

- [x] C-11: roles/alert-module/templates/alert-module.yaml.j2 생성
  - 파일: `roles/alert-module/templates/alert-module.yaml.j2`
  - 변경: Alert Module K8s manifest 템플릿
  ```yaml
  # TODO: Alert Module 버전 및 설정 확인 필요
  ---
  apiVersion: v1
  kind: Namespace
  metadata:
    name: alert-module
  ---
  # TODO: Alert Module Deployment, Service, ConfigMap 추가
  # Kafka 연동 설정 포함
  ```

- [x] C-12: roles/alert-module/defaults/main.yaml 생성
  - 파일: `roles/alert-module/defaults/main.yaml`
  - 변경: role 기본 변수 정의

---

## 4. 미결 사항

| 항목 | 관련 덩어리 | 상태 |
|---|---|---|
| 각 VM 실제 IP 주소 | A | # TODO |
| k8s-master IP (Terraform output) | A | # TODO |
| Keycloak realm/client 초기 설정값 | B | # TODO |
| 각 컴포넌트 이미지 버전 | B, C | # TODO |
| Kafka 세부 버전 및 설정 | C | # TODO |
| Alert Module 세부 버전 및 설정 | C | # TODO |
| CoreDNS / DNS Agent 설정값 | B | # TODO |
| FluentD FLUENT_FORWARD_HOST | B, C | # TODO |
| FluentD CLUSTER_DIVIDE_VALUE | B | # TODO |
| Console VM 컴포넌트 포트/환경변수 | B | # TODO |

---

## 5. 인라인 메모란

<!--
  사람이 검토하면서 메모를 남기는 공간입니다.
  Claude는 3단계에서 이 메모를 반영하여 plan.md를 업데이트합니다.

  예시:
  [메모] A-2: 여기서는 async로 처리해야 함
  [메모] B-1: 기존 함수명 유지할 것
  [질문] C-1: 이 방식이 맞나? 확인 필요
-->

(검토 메모를 여기에 작성)

---

## 변경 이력

| 날짜 | 변경 내용 |
|---|---|
| 2026-03-16 | 초안 작성 |
| 2026-03-16 | 전체 구조 계획 작성 (덩어리 A/B/C) |
