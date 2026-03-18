# modules/k8s-cluster/outputs.tf
# K8s 클러스터 VM 프로비저닝 출력값
# Ansible 인벤토리 생성에 활용

# ─────────────────────────────────────────────────────────────────────────────
# HAProxy 노드
# ─────────────────────────────────────────────────────────────────────────────

output "haproxy_ips" {
  description = "HAProxy 노드 IP 주소 목록"
  value       = openstack_compute_instance_v2.haproxy[*].access_ip_v4
}

output "haproxy_names" {
  description = "HAProxy 노드 이름 목록"
  value       = openstack_compute_instance_v2.haproxy[*].name
}

# ─────────────────────────────────────────────────────────────────────────────
# Master 노드
# ─────────────────────────────────────────────────────────────────────────────

output "master_ips" {
  description = "Master 노드 IP 주소 목록"
  value       = openstack_compute_instance_v2.master[*].access_ip_v4
}

output "master_names" {
  description = "Master 노드 이름 목록"
  value       = openstack_compute_instance_v2.master[*].name
}

# ─────────────────────────────────────────────────────────────────────────────
# Worker 노드
# ─────────────────────────────────────────────────────────────────────────────

output "worker_ips" {
  description = "Worker 노드 IP 주소 목록"
  value       = openstack_compute_instance_v2.worker[*].access_ip_v4
}

output "worker_names" {
  description = "Worker 노드 이름 목록"
  value       = openstack_compute_instance_v2.worker[*].name
}

# ─────────────────────────────────────────────────────────────────────────────
# NFS 노드
# ─────────────────────────────────────────────────────────────────────────────

output "nfs_ips" {
  description = "NFS 노드 IP 주소 목록"
  value       = openstack_compute_instance_v2.nfs[*].access_ip_v4
}

output "nfs_names" {
  description = "NFS 노드 이름 목록"
  value       = openstack_compute_instance_v2.nfs[*].name
}

# ─────────────────────────────────────────────────────────────────────────────
# 클러스터 정보 요약
# ─────────────────────────────────────────────────────────────────────────────

output "cluster_info" {
  description = "클러스터 요약 정보"
  value = {
    cluster_name      = var.cluster_name
    environment       = var.environment
    secloudit_version = var.secloudit_version
    cluster_type      = var.cluster_type
    node_counts = {
      haproxy = var.haproxy_count
      master  = var.master_count
      worker  = var.worker_count
      nfs     = var.nfs_count
    }
  }
}
