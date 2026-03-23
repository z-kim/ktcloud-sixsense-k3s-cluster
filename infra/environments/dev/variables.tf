# dev 환경 엔트리포인트에서 사용하는 입력 변수를 정의한다.
# AWS 리전, 네트워크 대역, NAT 모드, 인스턴스 타입, SSH 접근 조건을 관리한다.

variable "aws_region" {
  description = "AWS region for the dev environment."
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging."
  type        = string
  default     = "k3s-security"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner tag value."
  type        = string
  default     = "team-name"
}

variable "extra_tags" {
  description = "Additional tags merged into the common tag set."
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs for the two public subnets."
  type        = list(string)
  default     = ["10.10.0.0/24", "10.10.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for the two private subnets."
  type        = list(string)
  default     = ["10.10.10.0/24", "10.10.11.0/24"]
}

variable "preferred_primary_az" {
  description = "Preferred primary AZ for bastion, NAT, control-plane, and single-AZ placements."
  type        = string
  default     = "ap-northeast-2a"
}

variable "spread_workers_across_azs" {
  description = "Whether workers are allowed to spread across both private subnets/AZs."
  type        = bool
  default     = false
}

variable "admin_cidrs" {
  description = "CIDR blocks allowed to SSH into the bastion host."
  type        = list(string)
}

variable "key_name" {
  description = "Existing EC2 key pair name used for bastion and nodes."
  type        = string
}

variable "nat_mode" {
  description = "NAT mode for private subnet egress. Allowed values: instance or gateway."
  type        = string
  default     = "instance"

  validation {
    condition     = contains(["instance", "gateway"], var.nat_mode)
    error_message = "nat_mode must be either \"instance\" or \"gateway\"."
  }
}

variable "bastion_instance_type" {
  description = "Instance type for the bastion host."
  type        = string
  default     = "t3.micro"
}

variable "nat_instance_type" {
  description = "Instance type for the NAT instance."
  type        = string
  default     = "t3.micro"
}

variable "k3s_server_instance_type" {
  description = "Instance type for the K3s control-plane node."
  type        = string
  default     = "t3.small"
}

variable "k3s_worker_instance_type" {
  description = "Instance type for K3s worker nodes."
  type        = string
  default     = "t3.small"
}

variable "worker_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 1
}

variable "worker_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 1
}

variable "worker_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 2
}

variable "alb_http_port" {
  description = "HTTP listener port exposed by the ALB."
  type        = number
  default     = 80
}

variable "ingress_http_nodeport" {
  description = "Fixed NodePort used by ingress-nginx HTTP traffic."
  type        = number
  default     = 30080
}

variable "ingress_https_nodeport" {
  description = "Fixed NodePort used by ingress-nginx HTTPS traffic."
  type        = number
  default     = 30443
}

variable "enable_mysql_rds" {
  description = "Whether to create a private MySQL RDS instance for the app."
  type        = bool
  default     = false
}

variable "mysql_instance_class" {
  description = "Instance class for the MySQL RDS instance."
  type        = string
  default     = "db.t3.micro"
}

variable "mysql_allocated_storage" {
  description = "Allocated storage size in GiB for MySQL RDS."
  type        = number
  default     = 20
}

variable "mysql_max_allocated_storage" {
  description = "Maximum autoscaled storage size in GiB for MySQL RDS."
  type        = number
  default     = 100
}

variable "mysql_engine_version" {
  description = "MySQL engine version for RDS."
  type        = string
  default     = "8.0"
}

variable "mysql_db_name" {
  description = "Initial database name for MySQL RDS."
  type        = string
  default     = "app"
}

variable "mysql_username" {
  description = "Master username for MySQL RDS."
  type        = string
  default     = "appuser"
}

variable "mysql_password" {
  description = "Master password for MySQL RDS."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.mysql_password) >= 8
    error_message = "mysql_password must be at least 8 characters long."
  }
}

variable "mysql_backup_retention_period" {
  description = "Backup retention period in days for MySQL RDS."
  type        = number
  default     = 1
}

variable "mysql_multi_az" {
  description = "Whether to enable Multi-AZ for MySQL RDS."
  type        = bool
  default     = false
}
