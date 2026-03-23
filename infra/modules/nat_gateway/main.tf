# NAT gateway를 생성한다.
# Private subnet의 기본 라우트를 NAT gateway로 보낼 수 있도록 EIP와 함께 구성한다.

resource "aws_eip" "this" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip"
  })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.this.id
  subnet_id     = var.subnet_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-gateway"
  })
}
