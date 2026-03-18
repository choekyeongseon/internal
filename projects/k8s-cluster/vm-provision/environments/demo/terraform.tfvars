# environments/demo/terraform.tfvars
# Demo 환경 변수값

# ─────────────────────────────────────────────────────────────────────────────
# 클러스터 식별
# ─────────────────────────────────────────────────────────────────────────────

cluster_name      = "demo-k8s"
secloudit_version = "v2.0"  # v1.5 / v2.0 / v2.3 / v2.6
cluster_type      = "separated"

# ─────────────────────────────────────────────────────────────────────────────
# 노드 수
# TODO: demo 환경 노드 수 확인 필요
# ─────────────────────────────────────────────────────────────────────────────

master_count  = 1
worker_count  = 3
haproxy_count = 1
nfs_count     = 1

# ─────────────────────────────────────────────────────────────────────────────
# OpenStack 리소스 설정
# TODO: OpenStack flavor/이미지/네트워크 이름 확인 필요
# ─────────────────────────────────────────────────────────────────────────────

flavor_master  = "m1.large"     # TODO: 실제 flavor 이름으로 변경
flavor_worker  = "m1.large"     # TODO: 실제 flavor 이름으로 변경
flavor_haproxy = "m1.medium"    # TODO: 실제 flavor 이름으로 변경
flavor_nfs     = "m1.medium"    # TODO: 실제 flavor 이름으로 변경

image_name   = "Rocky-9-x86_64"  # TODO: 실제 이미지 이름으로 변경
network_name = "private-net"     # TODO: 실제 네트워크 이름으로 변경
keypair_name = "demo-keypair"    # TODO: 실제 키페어 이름으로 변경

security_groups = ["default"]

# ─────────────────────────────────────────────────────────────────────────────
# 태그
# ─────────────────────────────────────────────────────────────────────────────

tags = {
  project = "secloudit"
  owner   = "platform-team"
}
