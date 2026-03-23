# NAT instance를 생성한다.
# Private subnet의 아웃바운드 인터넷 접근을 위해 source/dest check를 끄고 NAT 설정 스크립트를 적용한다.

data "aws_ssm_parameter" "ubuntu_2204_ami" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.ubuntu_2204_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  associate_public_ip_address = true
  source_dest_check           = false
  user_data                   = templatefile("${path.module}/../../templates/nat_user_data.sh.tftpl", {})

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-instance"
  })
}
