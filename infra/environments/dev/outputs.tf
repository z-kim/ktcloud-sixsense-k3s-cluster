# dev 환경 배포 후 운영과 테스트에 필요한 핵심 출력을 정의한다.
# ALB DNS, Bastion IP, control-plane private IP, worker ASG 이름을 노출한다.

output "alb_dns_name" {
  description = "Public DNS name of the internet-facing ALB."
  value       = module.alb.dns_name
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host."
  value       = module.bastion.public_ip
}

output "k3s_server_private_ip" {
  description = "Private IP of the K3s control-plane node."
  value       = module.k3s_server.private_ip
}

output "worker_asg_name" {
  description = "Auto Scaling Group name for K3s workers."
  value       = module.k3s_worker_group.asg_name
}

output "k3s_join_token" {
  description = "K3s shared token used by server and agents."
  value       = random_password.k3s_token.result
  sensitive   = true
}

output "mysql_rds_endpoint" {
  description = "Endpoint of the MySQL RDS instance, if enabled."
  value       = var.enable_mysql_rds ? module.rds_mysql[0].endpoint : null
}

output "mysql_rds_database_url" {
  description = "Application DATABASE_URL value for MySQL RDS, if enabled."
  value       = var.enable_mysql_rds ? module.rds_mysql[0].database_url : null
  sensitive   = true
}
