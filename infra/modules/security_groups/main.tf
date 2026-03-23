# 보안 그룹을 역할별로 중앙 관리한다.
# Bastion, ALB, NAT, control-plane, worker, cluster 내부 통신 규칙을 SG 참조 중심으로 정의한다.

resource "aws_security_group" "bastion" {
  name        = "${var.name_prefix}-bastion-sg"
  description = "SSH entry point for operators."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-sg"
    Role = "bastion"
  })
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  for_each = toset(var.admin_cidrs)

  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = each.value
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "bastion_all" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Internet-facing ALB."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-sg"
    Role = "alb"
  })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "nat_instance" {
  name        = "${var.name_prefix}-nat-instance-sg"
  description = "NAT instance traffic from private subnets."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-instance-sg"
    Role = "nat-instance"
  })
}

resource "aws_vpc_security_group_ingress_rule" "nat_from_vpc" {
  security_group_id = aws_security_group.nat_instance.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "nat_all" {
  security_group_id = aws_security_group.nat_instance.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "cluster" {
  name        = "${var.name_prefix}-cluster-sg"
  description = "Shared east-west traffic for K3s nodes."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cluster-sg"
    Role = "k3s-cluster"
  })
}

resource "aws_vpc_security_group_ingress_rule" "cluster_self" {
  security_group_id            = aws_security_group.cluster.id
  referenced_security_group_id = aws_security_group.cluster.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_egress_rule" "cluster_all" {
  security_group_id = aws_security_group.cluster.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "control_plane" {
  name        = "${var.name_prefix}-control-plane-sg"
  description = "Additional access rules for the K3s server."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-control-plane-sg"
    Role = "k3s-control-plane"
  })
}

resource "aws_vpc_security_group_ingress_rule" "control_plane_ssh" {
  security_group_id            = aws_security_group.control_plane.id
  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
}

resource "aws_vpc_security_group_egress_rule" "control_plane_all" {
  security_group_id = aws_security_group.control_plane.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "worker" {
  name        = "${var.name_prefix}-worker-sg"
  description = "Worker SSH and ingress-nginx NodePort access."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-worker-sg"
    Role = "k3s-worker"
  })
}

resource "aws_vpc_security_group_ingress_rule" "worker_ssh" {
  security_group_id            = aws_security_group.worker.id
  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
}

resource "aws_vpc_security_group_ingress_rule" "worker_http_nodeport" {
  security_group_id            = aws_security_group.worker.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.ingress_http_nodeport
  ip_protocol                  = "tcp"
  to_port                      = var.ingress_http_nodeport
}

resource "aws_vpc_security_group_ingress_rule" "worker_https_nodeport" {
  security_group_id            = aws_security_group.worker.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.ingress_https_nodeport
  ip_protocol                  = "tcp"
  to_port                      = var.ingress_https_nodeport
}

resource "aws_vpc_security_group_egress_rule" "worker_all" {
  security_group_id = aws_security_group.worker.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-db-sg"
  description = "MySQL RDS access from K3s nodes."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-sg"
    Role = "mysql-rds"
  })
}

resource "aws_vpc_security_group_ingress_rule" "db_mysql_from_cluster" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = aws_security_group.cluster.id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306
}

resource "aws_vpc_security_group_egress_rule" "db_all" {
  security_group_id = aws_security_group.db.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
