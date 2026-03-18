# plan.md — k8s-cluster

> 작성일: 2026-03-16
> 상태: `완료`
> 현재 Phase: Phase 1 - 전체 구조 구축

---

## 1. 목표

Terraform + Ansible로 SECloudit PaaS 플랫폼용 K8s 클러스터를 자동으로 구축한다.

### 성공 기준
- [x] vm-provision 실행 시 OpenStack에 VM 생성됨 (HAProxy 1, Master 1, Worker N, NFS 1)
- [x] k8s-deploy 실행 시 K8s 클러스터 초기화 완료 (kubectl get nodes 정상)
- [x] OSS 컴포넌트 순서대로 설치 완료 (Calico → ... → Kafka)
- [x] 멱등성 보장 — 2회 연속 실행해도 오류 없음
- [x] secloudit_version 변수로 K8s/CRI-O 버전 자동 분기

---

## 2. 트레이드오프

| 결정 | 선택 | 이유 |
|---|---|---|
| 클러스터 구조 | 싱글 마스터 | Demo/QA 환경 용도, HA 불필요 |
| 컨테이너 런타임 | CRI-O | K8s 버전과 1:1 매핑, 폐쇄망 RPM 제공 |
| CNI | Calico | SECloudit 표준, NetworkPolicy 지원 |
| 버전 분기 위치 | group_vars/all.yaml | role 내부 조건문 최소화 |
| Terraform state | local (환경별 분리) | 단순성, QA workspace 활용 |

---

## 3. 구현 체크리스트

### 덩어리 A: vm-provision (Terraform)
<!-- 이 덩어리 = Claude Code 작업 지시 1회 단위 -->

- [x] A-1: vm-provision/ 디렉토리 구조 생성
  - 파일: `vm-provision/`
  - 변경: 디렉토리 생성 (modules/, environments/)

- [x] A-2: OpenStack Provider 설정
  - 파일: `vm-provision/versions.tf`
  - 변경: required_providers에 openstack 추가
  ```hcl
  terraform {
    required_providers {
      openstack = {
        source  = "terraform-provider-openstack/openstack"
        version = "~> 1.50"
      }
    }
  }
  ```

- [x] A-3: modules/k8s-cluster/ 변수 정의
  - 파일: `vm-provision/modules/k8s-cluster/variables.tf`
  - 변경: master_count, worker_count, flavor, image, network 등 변수 정의
  ```hcl
  variable "master_count" { default = 1 }
  variable "worker_count" { default = 3 }
  variable "flavor_name" { type = string }  # TODO: OpenStack flavor 이름 확인 필요
  variable "image_name" { type = string }   # TODO: OpenStack 이미지 이름 확인 필요
  variable "network_name" { type = string } # TODO: OpenStack 네트워크 이름 확인 필요
  ```

- [x] A-4: modules/k8s-cluster/ 리소스 정의 (compute)
  - 파일: `vm-provision/modules/k8s-cluster/main.tf`
  - 변경: openstack_compute_instance_v2 리소스 (haproxy, master, worker, nfs)

- [x] A-5: modules/k8s-cluster/ outputs 정의
  - 파일: `vm-provision/modules/k8s-cluster/outputs.tf`
  - 변경: IP 주소 출력 (haproxy_ip, master_ip, worker_ips, nfs_ip)

- [x] A-6: environments/demo/ 설정
  - 파일: `vm-provision/environments/demo/main.tf`, `terraform.tfvars`
  - 변경: demo 환경 모듈 호출, 변수값 설정
  ```hcl
  # TODO: demo 환경 노드 수, flavor 확인 필요
  worker_count = 3
  ```

- [x] A-7: environments/qa/ 설정
  - 파일: `vm-provision/environments/qa/main.tf`, `terraform.tfvars`
  - 변경: qa 환경 모듈 호출 (workspace: qa-{jira-ticket-id})
  ```hcl
  # TODO: qa 환경 노드 수, flavor 확인 필요
  ```

- [x] A-8: terraform.tfvars.example 작성
  - 파일: `vm-provision/terraform.tfvars.example`
  - 변경: 필수 변수 예시 (시크릿 제외)

- [x] A-9: vm-provision/README.md 작성
  - 파일: `vm-provision/README.md`
  - 변경: 사용법, 변수 목록, workspace 네이밍 규칙

### 덩어리 B: k8s-deploy 기본 (Ansible: OS ~ kubeadm init)
<!-- 이 덩어리 = Claude Code 작업 지시 1회 단위 -->

- [x] B-1: k8s-deploy/ 디렉토리 구조 생성
  - 파일: `k8s-deploy/`
  - 변경: 디렉토리 생성 (inventories/, group_vars/, roles/, playbooks/, templates/)

- [x] B-2: inventories/demo/ 작성
  - 파일: `k8s-deploy/inventories/demo/hosts.yaml`
  - 변경: 호스트 그룹 정의 (haproxy, masters, workers, nfs)
  ```yaml
  all:
    children:
      haproxy:
        hosts:
          haproxy-01:
            ansible_host: "{{ haproxy_ip }}"  # TODO: Terraform output 연동
      masters:
        hosts:
          master-01:
      workers:
        hosts:
          worker-01:
          worker-02:
          worker-03:
      nfs:
        hosts:
          nfs-01:
  ```

- [x] B-3: inventories/qa/ 작성
  - 파일: `k8s-deploy/inventories/qa/hosts.yaml`
  - 변경: qa 환경 인벤토리 (구조 동일, IP 다름)

- [x] B-4: group_vars/all.yaml 작성 (버전 매핑)
  - 파일: `k8s-deploy/group_vars/all.yaml`
  - 변경: 버전 변수 기반 구성 (K8s, CRI-O, OSS 버전은 언제든 변경 가능 → 변수 매핑으로 유연하게 관리)
  ```yaml
  # 기준 변수 (이 값만 변경하면 모든 버전 자동 분기)
  secloudit_version: "v1.5"  # v1.5 / v2.0 / v2.3 / v2.6

  # K8s 버전 매핑 (secloudit_version → k8s_version)
  k8s_version_map:
    v1.5: "1.23.17"
    v2.0: "1.27.8"
    # TODO: v2.3, v2.6 버전 확인 필요

  # 파생 변수 (자동 계산)
  k8s_version: "{{ k8s_version_map[secloudit_version] }}"
  crio_version: "{{ k8s_version | regex_replace('^(\\d+\\.\\d+).*', '\\1') }}"

  # OSS 버전 매핑 (필요 시 secloudit_version별 분기)
  oss_versions:
    calico: "3.25.0"      # TODO: 버전별 분기 필요 시 map 구조로 변경
    argocd: "2.8.0"
    # ... 기타 OSS
  ```

- [x] B-5: group_vars/masters.yaml 작성
  - 파일: `k8s-deploy/group_vars/masters.yaml`
  - 변경: kubeadm 설정값 (pod_cidr, service_cidr, api_server_endpoint)

- [x] B-6: group_vars/haproxy.yaml 작성
  - 파일: `k8s-deploy/group_vars/haproxy.yaml`
  - 변경: HAProxy 포트 분기
  ```yaml
  haproxy_api_frontend_port: "{{ '26443' if secloudit_version == 'v1.5' else '6443' }}"
  haproxy_http_nodeport: "{{ '30180' if secloudit_version == 'v1.5' else '30080' }}"
  haproxy_https_nodeport: "{{ '30181' if secloudit_version == 'v1.5' else '30443' }}"
  ```

- [x] B-7: roles/common/ 작성
  - 파일: `k8s-deploy/roles/common/tasks/main.yaml`
  - 변경: hostname 설정, /etc/hosts 구성, Harbor CA trust 등록 (update-ca-trust)

- [x] B-8: roles/k8s-preinstall/ 작성
  - 파일: `k8s-deploy/roles/k8s-preinstall/tasks/main.yaml`
  - 변경: SELinux permissive, swap off, 커널 모듈 (overlay, br_netfilter), sysctl, firewalld 설정

- [x] B-9: roles/k8s-install/ 작성
  - 파일: `k8s-deploy/roles/k8s-install/tasks/main.yaml`
  - 변경: CRI-O RPM 설치, kubelet/kubeadm/kubectl RPM 설치 (오프라인: disable_gpg_check, disablerepo)

- [x] B-10: roles/k8s-init/ 작성 (Master)
  - 파일: `k8s-deploy/roles/k8s-init/tasks/main.yaml`
  - 변경: kubeadm init (idempotency: /etc/kubernetes/admin.conf 존재 확인)
  ```yaml
  - name: kubeadm init 실행 (최초 1회)
    command: kubeadm init --config /etc/kubernetes/kubeadm-config.yaml
    when: not kubeadm_already_initialized
  ```

- [x] B-11: roles/k8s-init/ 작성 (Worker join)
  - 파일: `k8s-deploy/roles/k8s-init/tasks/join.yaml`
  - 변경: kubeadm join (idempotency: kubelet.conf 존재 확인, 토큰 재생성 처리)

- [x] B-12: templates/kubeadm-config.yaml.j2 작성
  - 파일: `k8s-deploy/templates/kubeadm-config.yaml.j2`
  - 변경: ClusterConfiguration 템플릿 (kubernetesVersion, controlPlaneEndpoint 등)

- [x] B-13: playbooks/build-cluster.yaml 작성 (덩어리 B 범위)
  - 파일: `k8s-deploy/playbooks/build-cluster.yaml`
  - 변경: common → k8s-preinstall → k8s-install → k8s-init 순서 호출

- [x] B-14: k8s-deploy/README.md 작성
  - 파일: `k8s-deploy/README.md`
  - 변경: 사용법, 변수 목록, 실행 순서

### 덩어리 C: k8s-deploy OSS (Ansible: Calico ~ Kafka)
<!-- 이 덩어리 = Claude Code 작업 지시 1회 단위 -->

- [x] C-1: roles/k8s-oss/ 디렉토리 구조 생성
  - 파일: `k8s-deploy/roles/k8s-oss/`
  - 변경: tasks/, files/, templates/ 생성

- [x] C-2: roles/k8s-oss/tasks/calico.yaml 작성
  - 파일: `k8s-deploy/roles/k8s-oss/tasks/calico.yaml`
  - 변경: Calico manifest 적용 (Worker join 전 실행 필수)

- [x] C-3: roles/k8s-oss/tasks/ingress.yaml 작성
  - 파일: `k8s-deploy/roles/k8s-oss/tasks/ingress.yaml`
  - 변경: Ingress Controller 설치

- [x] C-4: roles/k8s-oss/tasks/nfs_provisioner.yaml 작성
  - 파일: `k8s-deploy/roles/k8s-oss/tasks/nfs_provisioner.yaml`
  - 변경: NFS Provisioner 설치 (StorageClass 생성)

- [x] C-5: roles/k8s-oss/tasks/metrics_server.yaml 작성
  - 파일: `k8s-deploy/roles/k8s-oss/tasks/metrics_server.yaml`
  - 변경: Metrics Server 설치 (--kubelet-insecure-tls, hostNetwork: true 패치)

- [x] C-6: roles/k8s-oss/tasks/prometheus.yaml 작성
  - 파일: `k8s-deploy/roles/k8s-oss/tasks/prometheus.yaml`
  - 변경: Prometheus 설치

- [x] C-7: roles/k8s-oss/tasks/argocd.yaml 작성
  - 파일: `k8s-deploy/roles/k8s-oss/tasks/argocd.yaml`
  - 변경: ArgoCD 설치 (워커 3대 미만 시 podAntiAffinity 제거 패치)

- [x] C-8: roles/k8s-oss/tasks/tekton.yaml 작성
  - 파일: `k8s-deploy/roles/k8s-oss/tasks/tekton.yaml`
  - 변경: Tekton 설치

- [x] C-9: roles/k8s-oss/tasks/istio.yaml 작성
  - 파일: `k8s-deploy/roles/k8s-oss/tasks/istio.yaml`
  - 변경: Istio 설치

- [x] C-10: roles/k8s-oss/tasks/kafka.yaml 작성
  - 파일: `k8s-deploy/roles/k8s-oss/tasks/kafka.yaml`
  - 변경: Kafka 설치

- [x] C-11: roles/k8s-oss/tasks/main.yaml 작성 (순서 고정)
  - 파일: `k8s-deploy/roles/k8s-oss/tasks/main.yaml`
  - 변경: import_tasks 순서 고정
  ```yaml
  - import_tasks: calico.yaml
  - import_tasks: ingress.yaml
  - import_tasks: nfs_provisioner.yaml
  - import_tasks: metrics_server.yaml
  - import_tasks: prometheus.yaml
  - import_tasks: argocd.yaml
  - import_tasks: tekton.yaml
  - import_tasks: istio.yaml
  - import_tasks: kafka.yaml
  ```

- [x] C-12: playbooks/build-cluster.yaml 업데이트 (덩어리 C 범위 추가)
  - 파일: `k8s-deploy/playbooks/build-cluster.yaml`
  - 변경: k8s-init 후 k8s-oss 호출 추가 (Calico는 Worker join 전, 나머지는 후)

---

## 4. 미결 사항

| 항목 | 관련 덩어리 | 상태 |
|---|---|---|
| v2.0 / v2.3 현장 K8s 버전 | B (group_vars/all.yaml) | # TODO |
| v2.6 K8s 버전 | B (group_vars/all.yaml) | # TODO |
| demo / qa 클러스터 노드 수 및 사양 | A (environments/) | # TODO |
| OpenStack flavor 이름 | A (variables.tf) | # TODO |
| OpenStack 네트워크 이름 | A (variables.tf) | # TODO |
| OpenStack 이미지 이름 | A (variables.tf) | # TODO |
| QA 클러스터 수명 관리 방식 | A (qa workspace) | # TODO |
| Jira 티켓 필드 정의 | A (qa workspace 네이밍) | # TODO |

---

## 5. 인라인 메모란

<!--
  사람이 검토하면서 메모를 남기는 공간입니다.
  Claude는 3단계에서 이 메모를 반영하여 plan.md를 업데이트합니다.

  예시:
  [메모] A-3: flavor_name 기본값 설정할 것
  [메모] B-10: kubeadm init 전에 swap off 확인 추가
  [질문] C-7: ArgoCD HA 패치 조건 확인 필요
-->

(검토 메모를 여기에 작성)

---

## 변경 이력

| 날짜         | 변경 내용                                                                  |
| ---------- | ---------------------------------------------------------------------- |
| 2026-03-16 | 초안 작성 — 3개 덩어리 (A: vm-provision, B: k8s-deploy 기본, C: k8s-deploy OSS)  |
| 2026-03-16 | 메모 반영 — vm-provisioning → vm-provision 변경, B-4 버전 매핑 구조 개선 (OSS 버전 포함) |
