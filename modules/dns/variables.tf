variable "domain" {
  description = "domain name"
  type        = string
}

variable "alb_dns_name" {
  type        = string
  description = "DNS name of the load balancer"
}

variable "alb_zone_id" {
  type        = string
  description = "Hosted zone ID of the load balancer"
}
