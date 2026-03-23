# dev 환경 전반에서 재사용하는 공통 값과 bootstrap 파일 경로를 정의한다.

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  sorted_azs = contains(data.aws_availability_zones.available.names, var.preferred_primary_az) ? concat(
    [var.preferred_primary_az],
    [for az in data.aws_availability_zones.available.names : az if az != var.preferred_primary_az]
  ) : data.aws_availability_zones.available.names
  azs = slice(local.sorted_azs, 0, 2)

  default_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
    },
    var.extra_tags
  )
}
