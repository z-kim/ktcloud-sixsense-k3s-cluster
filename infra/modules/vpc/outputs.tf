output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = values(aws_subnet.public)[*].id
}

output "private_subnet_ids" {
  value = values(aws_subnet.private)[*].id
}

output "private_route_table_ids" {
  value = values(aws_route_table.private)[*].id
}

output "private_route_table_ids_by_key" {
  value = {
    for key, route_table in aws_route_table.private :
    key => route_table.id
  }
}
