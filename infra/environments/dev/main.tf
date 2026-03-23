# dev 환경의 인프라 조합을 정의한다.
# 네트워크, ALB, K3s, MySQL RDS를 한 엔트리포인트에서 조합한다.

module "vpc" {
  source = "../../modules/vpc"

  name                 = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  azs                  = local.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = local.default_tags
}

module "security_groups" {
  source = "../../modules/security_groups"

  name_prefix            = local.name_prefix
  vpc_id                 = module.vpc.vpc_id
  vpc_cidr               = var.vpc_cidr
  admin_cidrs            = var.admin_cidrs
  ingress_http_nodeport  = var.ingress_http_nodeport
  ingress_https_nodeport = var.ingress_https_nodeport
  tags                   = local.default_tags
}

module "nat_instance" {
  count  = var.nat_mode == "instance" ? 1 : 0
  source = "../../modules/nat_instance"

  name_prefix       = local.name_prefix
  subnet_id         = module.vpc.public_subnet_ids[0]
  security_group_id = module.security_groups.nat_instance_sg_id
  instance_type     = var.nat_instance_type
  tags              = merge(local.default_tags, { Role = "nat-instance", Tier = "public" })
}

module "nat_gateway" {
  count  = var.nat_mode == "gateway" ? 1 : 0
  source = "../../modules/nat_gateway"

  name_prefix = local.name_prefix
  subnet_id   = module.vpc.public_subnet_ids[0]
  tags        = merge(local.default_tags, { Role = "nat-gateway", Tier = "public" })
}

resource "aws_route" "private_nat_instance" {
  for_each = var.nat_mode == "instance" ? module.vpc.private_route_table_ids_by_key : {}

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = module.nat_instance[0].network_interface_id
}

resource "aws_route" "private_nat_gateway" {
  for_each = var.nat_mode == "gateway" ? module.vpc.private_route_table_ids_by_key : {}

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = module.nat_gateway[0].nat_gateway_id
}

module "bastion" {
  source = "../../modules/bastion"

  name_prefix       = local.name_prefix
  subnet_id         = module.vpc.public_subnet_ids[0]
  security_group_id = module.security_groups.bastion_sg_id
  key_name          = var.key_name
  instance_type     = var.bastion_instance_type
  tags              = merge(local.default_tags, { Role = "bastion", Tier = "public" })
}

module "alb" {
  source = "../../modules/alb"

  name_prefix   = local.name_prefix
  subnet_ids    = module.vpc.public_subnet_ids
  vpc_id        = module.vpc.vpc_id
  sg_id         = module.security_groups.alb_sg_id
  listener_port = var.alb_http_port
  target_port   = var.ingress_http_nodeport
  tags          = merge(local.default_tags, { Role = "alb", Tier = "public" })
}

resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

module "k3s_server" {
  source = "../../modules/k3s_server"

  name_prefix        = local.name_prefix
  subnet_id          = module.vpc.private_subnet_ids[0]
  security_group_ids = [module.security_groups.cluster_sg_id, module.security_groups.control_plane_sg_id]
  key_name           = var.key_name
  instance_type      = var.k3s_server_instance_type
  tags               = merge(local.default_tags, { Role = "k3s-control-plane", Tier = "private" })
}

module "k3s_worker_group" {
  source = "../../modules/k3s_worker_group"

  name_prefix        = local.name_prefix
  subnet_ids         = var.spread_workers_across_azs ? module.vpc.private_subnet_ids : [module.vpc.private_subnet_ids[0]]
  security_group_ids = [module.security_groups.cluster_sg_id, module.security_groups.worker_sg_id]
  key_name           = var.key_name
  instance_type      = var.k3s_worker_instance_type
  server_private_ip  = module.k3s_server.private_ip
  k3s_token          = random_password.k3s_token.result
  desired_size       = var.worker_desired_size
  min_size           = var.worker_min_size
  max_size           = var.worker_max_size
  target_group_arns  = [module.alb.target_group_arn]
  tags               = merge(local.default_tags, { Role = "k3s-worker", Tier = "private" })
}

module "rds_mysql" {
  count  = var.enable_mysql_rds ? 1 : 0
  source = "../../modules/rds_mysql"

  name_prefix             = local.name_prefix
  subnet_ids              = module.vpc.private_subnet_ids
  security_group_ids      = [module.security_groups.db_sg_id]
  instance_class          = var.mysql_instance_class
  allocated_storage       = var.mysql_allocated_storage
  max_allocated_storage   = var.mysql_max_allocated_storage
  engine_version          = var.mysql_engine_version
  availability_zone       = local.azs[0]
  db_name                 = var.mysql_db_name
  username                = var.mysql_username
  password                = var.mysql_password
  backup_retention_period = var.mysql_backup_retention_period
  multi_az                = var.mysql_multi_az
  tags                    = merge(local.default_tags, { Role = "mysql-rds", Tier = "private" })
}
