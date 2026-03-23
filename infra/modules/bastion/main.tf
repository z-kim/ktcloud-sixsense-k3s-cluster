# Bastion EC2 인스턴스를 생성한다.
# 운영자는 이 호스트를 통해 private subnet의 K3s 노드에 SSH 접속한다.

data "aws_ssm_parameter" "ubuntu_2204_ami" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.ubuntu_2204_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion"
  })
}
