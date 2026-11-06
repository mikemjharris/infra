output "zone_id" {
  description = "Read by the sites layer to add its records."
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "Set these at the registrar (123-Reg) to switch DNS to Route 53."
  value       = aws_route53_delegation_set.main.name_servers
}
