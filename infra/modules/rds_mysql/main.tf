# MySQL RDS 인스턴스를 private subnet에 생성한다.
# 애플리케이션은 별도 Secret에 DATABASE_URL을 주입해 사용한다.

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-mysql-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-mysql-subnet-group"
  })
}

resource "aws_db_instance" "this" {
  identifier              = "${var.name_prefix}-mysql"
  engine                  = "mysql"
  engine_version          = var.engine_version
  availability_zone       = var.multi_az ? null : var.availability_zone
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  max_allocated_storage   = var.max_allocated_storage
  db_name                 = var.db_name
  username                = var.username
  password                = var.password
  port                    = 3306
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = var.security_group_ids
  publicly_accessible     = false
  storage_encrypted       = true
  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  deletion_protection     = false
  skip_final_snapshot     = true
  apply_immediately       = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-mysql"
  })
}
