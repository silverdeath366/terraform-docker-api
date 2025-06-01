output "load_balancer_dns" {
  value = aws_lb.api_lb.dns_name
}
