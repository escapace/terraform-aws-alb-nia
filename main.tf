provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS Region"
  type = string
}

variable "services" {
  description = "Consul services monitored by Consul-Terraform-Sync"
  type = map(
    object({
      id        = string
      name      = string
      kind      = string
      address   = string
      port      = number
      meta      = map(string)
      tags      = list(string)
      namespace = string
      status    = string

      node                  = string
      node_id               = string
      node_address          = string
      node_datacenter       = string
      node_tagged_addresses = map(string)
      node_meta             = map(string)

      cts_user_defined_meta = map(string)
    })
  )
}

variable "listener_arn" {
  type        = string
  description = "Listener ARN on Application Load Balancer."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to attach a target group for Consul ingress gateway."
}

locals {
  exclude_kind = ["ingress-gateway", "connect-proxy"]

  services = distinct([for service in values(var.services) : service if !contains(local.exclude_kind, service.kind) && service.status == "passing" && try(tobool(service.meta.alb_enabled), false)])
  names = distinct([for service in local.services : service.name])

  attachments = {for name in local.names : name => [for service in local.services : {
    port              = tonumber(service.port)
    availability_zone = service.node_meta.availability_zone
    address           = service.address
  } if service.name == name]}

  meta = { for name in local.names : name => merge([for service in local.services : {
    deregistration_delay             = try(tonumber(service.meta.alb_deregistration_delay), null)
    preserve_client_ip               = try(tobool(service.meta.alb_preserve_client_ip), null)
    protocol_version                 = try(service.meta.alb_protocol_version, "HTTP1")
    protocol                         = try(service.meta.alb_protocol, "HTTP")
    slow_start                       = try(service.meta.alb_slow_start, null)
    load_balancing_algorithm_type    = try(service.meta.alb_load_balancing_algorithm_type, "round_robin")
    stickiness_enabled               = try(tobool(service.meta.alb_stickiness_enabled), true)
    stickiness_cookie_duration       = try(tonumber(service.meta.alb_stickiness_cookie_duration), null)
    stickiness_cookie_name           = try(service.meta.stickiness_cookie_name, null)
    stickiness_type                  = try(service.meta.alb_stickiness_type, "lb_cookie")
    host_headers                     = try(compact(distinct(jsondecode(service.meta.alb_host_headers))), [])
    http_headers                     = try(compact(distinct(jsondecode(service.meta.alb_http_headers))), [])
    http_request_methods             = try(compact(distinct(jsondecode(service.meta.alb_http_request_methods))), [])
    path_patterns                    = try(compact(distinct(jsondecode(service.meta.alb_path_patterns))), [])

    health_check_enabled             = try(tobool(service.meta.alb_health_check_enabled), null)
    health_check_healthy_threshold   = try(tonumber(service.meta.alb_health_check_healthy_threshold), null)
    health_check_interval            = try(tonumber(service.meta.alb_health_check_interval), null)
    health_check_matcher             = try(service.meta.alb_health_check_matcher, null)
    health_check_path                = try(service.meta.alb_health_check_path, null)
    health_check_timeout             = try(tonumber(service.meta.alb_health_check_timeout), null)
    health_check_unhealthy_threshold = try(tonumber(service.meta.alb_health_check_unhealthy_threshold), null)

    priority                         = try(tonumber(service.meta.alb_priority), null)
  } if service.name == name]...) }

  rules = { for name in local.names : name => merge(local.meta[name], {
    name        = name
    attachments = local.attachments[name]
  }) }
}

module "rule" {
  source = "./modules/rule"

  for_each = local.rules

  name                             = each.value.name
  attachments                      = each.value.attachments

  deregistration_delay             = each.value.deregistration_delay
  load_balancing_algorithm_type    = each.value.load_balancing_algorithm_type
  preserve_client_ip               = each.value.preserve_client_ip
  protocol_version                 = each.value.protocol_version
  protocol                         = each.value.protocol
  slow_start                       = each.value.slow_start
  stickiness_enabled               = each.value.stickiness_enabled
  stickiness_cookie_duration       = each.value.stickiness_cookie_duration
  stickiness_cookie_name           = each.value.stickiness_cookie_name
  stickiness_type                  = each.value.stickiness_type
  host_headers                     = each.value.host_headers
  http_headers                     = each.value.http_headers
  http_request_methods             = each.value.http_request_methods
  path_patterns                    = each.value.path_patterns

  health_check_enabled             = each.value.health_check_enabled
  health_check_healthy_threshold   = each.value.health_check_healthy_threshold
  health_check_interval            = each.value.health_check_interval
  health_check_matcher             = each.value.health_check_matcher
  health_check_path                = each.value.health_check_path
  health_check_timeout             = each.value.health_check_timeout
  health_check_unhealthy_threshold = each.value.health_check_unhealthy_threshold

  priority                         = each.value.priority

  listener_arn = var.listener_arn
  vpc_id       = var.vpc_id
}

# resource "null_resource" "null_resource" {
#   provisioner "local-exec" {
#     command = "echo '${jsonencode(local.values)}' | jq > test.json"
#   }
#
#   triggers = {
#     values = sha1(jsonencode(local.values))
#   }
# }

