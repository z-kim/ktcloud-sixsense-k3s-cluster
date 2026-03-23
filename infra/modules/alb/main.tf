# 외부 인터넷 진입점인 ALB와 listener, target group을 생성한다.
# ALB는 worker node의 ingress-nginx HTTP NodePort로 트래픽을 전달한다.

resource "aws_lb" "this" {
  name               = substr("${var.name_prefix}-alb", 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.sg_id]
  subnets            = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb"
  })
}

resource "aws_lb_target_group" "this" {
  name        = substr("${var.name_prefix}-ingress", 0, 32)
  port        = var.target_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/"
    matcher             = "200-404"
    interval            = 20
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ingress-tg"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
