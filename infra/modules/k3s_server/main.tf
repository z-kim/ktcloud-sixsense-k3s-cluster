# K3s control-plane EC2를 생성한다.
# 노드 설정과 K3s 설치는 이후 Ansible이 수행한다.

data "aws_ssm_parameter" "ubuntu_2204_ami" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

resource "aws_instance" "this" {
  ami                    = data.aws_ssm_parameter.ubuntu_2204_ami.value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-k3s-server"
  })
}
