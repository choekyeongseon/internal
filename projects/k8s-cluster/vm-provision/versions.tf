# vm-provision/versions.tf
# Terraform 및 Provider 버전 설정
# 대상: SECloudit K8s 클러스터 VM 프로비저닝

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
