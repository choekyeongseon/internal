CLAUDE.md와 research.md를 읽고 plan.md를 작성해라.
아직 구현하지 마라.

plan.md에 포함할 항목:
1. 목표 및 성공 기준
2. 트레이드오프
3. 구현 체크리스트 — 아래 3개 덩어리로 그룹화
4. 미결 사항 (미확인 항목 반영)
5. 인라인 메모란

---

덩어리 구분:

덩어리 A — vm-provisioning (Terraform)
- OpenStack Provider 설정
- modules/k8s-cluster/ 모듈 작성
  (HAProxy 1대, Master 1대, Worker N대, NFS 1대)
- environments/demo/, environments/qa/ 작성
- variables.tf, terraform.tfvars.example 작성

덩어리 B — k8s-deploy 기본 (Ansible: OS ~ kubeadm init)
- inventories/demo/, inventories/qa/ 작성
- group_vars/all.yaml (k8s_version, crio_version 버전 매핑)
- group_vars/masters.yaml (kubeadm 설정값)
- group_vars/haproxy.yaml (포트 분기)
- roles/common/ (hostname, /etc/hosts, Harbor CA trust)
- roles/k8s-preinstall/ (SELinux, swap, 커널 모듈, sysctl, firewalld)
- roles/k8s-install/ (CRI-O, kubelet/kubeadm/kubectl RPM)
- roles/k8s-init/ (kubeadm init + idempotency 처리)
- templates/kubeadm-config.yaml.j2
- playbooks/build-cluster.yaml (덩어리 B 범위)

덩어리 C — k8s-deploy OSS (Ansible: Calico ~ Kafka)
- roles/k8s-oss/ 하위 태스크 파일들:
  calico.yaml → ingress.yaml → nfs_provisioner.yaml → metrics_server.yaml
  → prometheus.yaml → argocd.yaml → tekton.yaml → istio.yaml → kafka.yaml
  → main.yaml (순서 고정 import)
- playbooks/build-cluster.yaml (덩어리 C 범위 추가)

---

체크리스트 작성 규칙:
- 각 항목은 - [ ] 형식
- 항목 1개 = git 커밋 1개 단위
- 미확인 항목(OpenStack flavor 이름, 네트워크 이름 등)은
  placeholder로 표시하고 # TODO 주석 달기

작성 완료 후 plan.md 주요 내용을 요약해서 보고해라.


