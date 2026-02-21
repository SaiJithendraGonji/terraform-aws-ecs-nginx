output "alb_dns_name" {
  description = "DNS name of the ALB - point your domain here"
  value       = aws_lb.nginx_alb.dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.nginx_cluster.name
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.rds.endpoint
  sensitive   = true
}

output "rds_secret_arn" {
  description = "Secrets Manager ARN for RDS credentials, managed by RDS"
  value       = aws_db_instance.rds.master_user_secret[0].secret_arn
}