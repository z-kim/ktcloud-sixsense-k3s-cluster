# K3s worker Auto Scaling Group을 생성한다.
# Launch Template user_data로 k3s agent를 자동 조인시키고 ALB target group에 등록한다.

data "aws_ssm_parameter" "ubuntu_2204_ami" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.name_prefix}-worker-"
  image_id      = data.aws_ssm_parameter.ubuntu_2204_ami.value
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = var.security_group_ids

  user_data = base64encode(templatefile("${path.module}/../../templates/k3s_worker_user_data.sh.tftpl", {
    server_private_ip = var.server_private_ip
    k3s_token         = var.k3s_token
  }))

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(var.tags, {
      Name = "${var.name_prefix}-k3s-worker"
    })
  }
}

resource "aws_autoscaling_group" "this" {
  name                = "${var.name_prefix}-worker-asg"
  desired_capacity    = var.desired_size
  min_size            = var.min_size
  max_size            = var.max_size
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = var.target_group_arns
  health_check_type   = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-k3s-worker"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
