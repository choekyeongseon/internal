# environments/demo/main.tf
# Demo 환경 K8s 클러스터 프로비저닝

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.50"
    }
  }
}

# OpenStack Provider 설정
# 인증 정보는 환경변수 또는 clouds.yaml로 주입
provider "openstack" {
  # OS_AUTH_URL, OS_USERNAME, OS_PASSWORD 등 환경변수 사용
  # 또는 cloud = "openstack" 으로 clouds.yaml 참조
}

# ─────────────────────────────────────────────────────────────────────────────
# K8s 클러스터 모듈 호출
# ─────────────────────────────────────────────────────────────────────────────

module "k8s_cluster" {
  source = "../../modules/k8s-cluster"

  # 클러스터 식별
  cluster_name      = var.cluster_name
  environment       = "demo"
  secloudit_version = var.secloudit_version
  cluster_type      = var.cluster_type

  # 노드 수
  master_count  = var.master_count
  worker_count  = var.worker_count
  haproxy_count = var.haproxy_count
  nfs_count     = var.nfs_count

  # OpenStack 리소스
  flavor_master  = var.flavor_master
  flavor_worker  = var.flavor_worker
  flavor_haproxy = var.flavor_haproxy
  flavor_nfs     = var.flavor_nfs
  image_name     = var.image_name
  network_name   = var.network_name
  keypair_name   = var.keypair_name
  security_groups = var.security_groups

  # 태그
  tags = var.tags
}

# ─────────────────────────────────────────────────────────────────────────────
# 출력값 전달
# ─────────────────────────────────────────────────────────────────────────────

output "haproxy_ips" {
  description = "HAProxy 노드 IP 주소 목록"
  value       = module.k8s_cluster.haproxy_ips
}

output "master_ips" {
  description = "Master 노드 IP 주소 목록"
  value       = module.k8s_cluster.master_ips
}

output "worker_ips" {
  description = "Worker 노드 IP 주소 목록"
  value       = module.k8s_cluster.worker_ips
}

output "nfs_ips" {
  description = "NFS 노드 IP 주소 목록"
  value       = module.k8s_cluster.nfs_ips
}

output "cluster_info" {
  description = "클러스터 요약 정보"
  value       = module.k8s_cluster.cluster_info
}
