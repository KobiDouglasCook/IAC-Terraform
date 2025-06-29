# Route 53 - creates zone for type of traffic
resource "aws_route53_zone" "primary" {
  name = var.domain
}

# Route 53 - routes ipv4 queries to load balancer
resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = "a8f257e8051c84e4a8ca2269fb96d1e1-1662753585.us-east-1.elb.amazonaws.com"
    zone_id                = "Z35SXDOTRQ7X7K"
    evaluate_target_health = true
  }
}
