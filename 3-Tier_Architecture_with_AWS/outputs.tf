# Output values for the 3-tier architecture

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main_vpc.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}

output "internet_facing_lb_dns" {
  description = "DNS name of the internet-facing load balancer"
  value       = aws_lb.internet_facing_lb.dns_name
}

# output "internal_lb_dns" {
#   description = "DNS name of the internal load balancer"
#   value       = aws_lb.internal_lb.dns_name
# }

output "bastion_host_public_ip" {
  description = "Public IP address of the bastion host"
  value       = aws_instance.bastion_host.public_ip
}


output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.main_nat.id
}

output "database_master_endpoint" {
  description = "Endpoint of the master RDS database"
  value       = aws_db_instance.database_master.endpoint
}

output "database_slave_endpoint" {
  description = "Endpoint of the slave RDS database"
  value       = aws_db_instance.database_slave.endpoint
}

output "database_port" {
  description = "Port of the RDS databases"
  value       = aws_db_instance.database_master.port
}