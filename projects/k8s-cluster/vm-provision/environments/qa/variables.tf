# environments/qa/variables.tf
# QA 환경 변수 정의

# ─────────────────────────────────────────────────────────────────────────────
# 클러스터 식별
# ─────────────────────────────────────────────────────────────────────────────

variable "cluster_name" {
  description = "클러스터 이름 (workspace 사용 시 무시됨)"
  type        = string
  default     = "qa-k8s"
}

variable "jira_ticket_id" {
  description = "Jira 티켓 ID (예: ST-42)"
  type        = string
  default     = ""
  # TODO: Jira 티켓 필드 정의 확인 필요
}

variable "secloudit_version" {
  description = "SECloudit 버전 (v1.5 / v2.0 / v2.3 / v2.6)"
  type        = string
}

variable "cluster_type" {
  description = "클러스터 타입 (all-in-one / separated)"
  type        = string
  default     = "separated"
}

# ─────────────────────────────────────────────────────────────────────────────
# 노드 수
# ─────────────────────────────────────────────────────────────────────────────

variable "master_count" {
  description = "마스터 노드 수 (싱글 마스터: 1)"
  type        = number
  default     = 1
}

variable "worker_count" {
  description = "워커 노드 수"
  type        = number
  default     = 3
  # TODO: qa 환경 노드 수 확인 필요
}

variable "haproxy_count" {
  description = "HAProxy 노드 수"
  type        = number
  default     = 1
}

variable "nfs_count" {
  description = "NFS 노드 수"
  type        = number
  default     = 1
}

# ─────────────────────────────────────────────────────────────────────────────
# OpenStack 리소스 설정
# ─────────────────────────────────────────────────────────────────────────────

variable "flavor_master" {
  description = "마스터 노드 flavor 이름"
  type        = string
  # TODO: OpenStack flavor 이름 확인 필요
}

variable "flavor_worker" {
  description = "워커 노드 flavor 이름"
  type        = string
  # TODO: OpenStack flavor 이름 확인 필요
}

variable "flavor_haproxy" {
  description = "HAProxy 노드 flavor 이름"
  type        = string
  # TODO: OpenStack flavor 이름 확인 필요
}

variable "flavor_nfs" {
  description = "NFS 노드 flavor 이름"
  type        = string
  # TODO: OpenStack flavor 이름 확인 필요
}

variable "image_name" {
  description = "VM 이미지 이름 (Rocky Linux 9.x)"
  type        = string
  # TODO: OpenStack 이미지 이름 확인 필요
}

variable "network_name" {
  description = "네트워크 이름"
  type        = string
  # TODO: OpenStack 네트워크 이름 확인 필요
}

variable "keypair_name" {
  description = "SSH 키페어 이름"
  type        = string
}

variable "security_groups" {
  description = "보안 그룹 목록"
  type        = list(string)
  default     = ["default"]
}

# ─────────────────────────────────────────────────────────────────────────────
# 태그
# ─────────────────────────────────────────────────────────────────────────────

variable "tags" {
  description = "추가 태그"
  type        = map(string)
  default     = {}
}
