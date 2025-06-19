output "route53_nameservers" {
  value = aws_route53_zone.primary.name_servers
}
