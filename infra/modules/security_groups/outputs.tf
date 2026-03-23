output "bastion_sg_id" {
  value = aws_security_group.bastion.id
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "nat_instance_sg_id" {
  value = aws_security_group.nat_instance.id
}

output "cluster_sg_id" {
  value = aws_security_group.cluster.id
}

output "control_plane_sg_id" {
  value = aws_security_group.control_plane.id
}

output "worker_sg_id" {
  value = aws_security_group.worker.id
}

output "db_sg_id" {
  value = aws_security_group.db.id
}
