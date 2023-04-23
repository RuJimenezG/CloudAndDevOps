output "endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.rds_postgresql.endpoint
}
