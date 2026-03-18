# modules/k8s-cluster/main.tf
# K8s 클러스터 VM 프로비저닝 메인 리소스
# 대상: HAProxy, Master, Worker, NFS 노드

# ─────────────────────────────────────────────────────────────────────────────
# 공통 태그
# ─────────────────────────────────────────────────────────────────────────────

locals {
  common_tags = merge(
    {
      cluster_name      = var.cluster_name
      environment       = var.environment
      secloudit_version = var.secloudit_version
      cluster_type      = var.cluster_type
      managed_by        = "terraform"
    },
    var.tags
  )
}

# ─────────────────────────────────────────────────────────────────────────────
# HAProxy 노드
# ─────────────────────────────────────────────────────────────────────────────

resource "openstack_compute_instance_v2" "haproxy" {
  count = var.haproxy_count

  name            = "${var.cluster_name}-haproxy-${format("%02d", count.index + 1)}"
  flavor_name     = var.flavor_haproxy
  image_name      = var.image_name
  key_pair        = var.keypair_name
  security_groups = var.security_groups

  network {
    name = var.network_name
  }

  metadata = local.common_tags
}

# ─────────────────────────────────────────────────────────────────────────────
# Master 노드 (싱글 마스터)
# ─────────────────────────────────────────────────────────────────────────────

resource "openstack_compute_instance_v2" "master" {
  count = var.master_count

  name            = "${var.cluster_name}-master-${format("%02d", count.index + 1)}"
  flavor_name     = var.flavor_master
  image_name      = var.image_name
  key_pair        = var.keypair_name
  security_groups = var.security_groups

  network {
    name = var.network_name
  }

  metadata = local.common_tags
}

# ─────────────────────────────────────────────────────────────────────────────
# Worker 노드
# ─────────────────────────────────────────────────────────────────────────────

resource "openstack_compute_instance_v2" "worker" {
  count = var.worker_count

  name            = "${var.cluster_name}-worker-${format("%02d", count.index + 1)}"
  flavor_name     = var.flavor_worker
  image_name      = var.image_name
  key_pair        = var.keypair_name
  security_groups = var.security_groups

  network {
    name = var.network_name
  }

  metadata = local.common_tags
}

# ─────────────────────────────────────────────────────────────────────────────
# NFS 노드
# ─────────────────────────────────────────────────────────────────────────────

resource "openstack_compute_instance_v2" "nfs" {
  count = var.nfs_count

  name            = "${var.cluster_name}-nfs-${format("%02d", count.index + 1)}"
  flavor_name     = var.flavor_nfs
  image_name      = var.image_name
  key_pair        = var.keypair_name
  security_groups = var.security_groups

  network {
    name = var.network_name
  }

  metadata = local.common_tags
}
