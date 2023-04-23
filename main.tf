provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS Region"
  type        = string
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

  services = distinct([
    for service in values(var.services) : service
    if !contains(local.exclude_kind, service.kind)
    && service.status == "passing"
    && try(tobool(service.meta.alb_enabled), false)
  ])

  service_names = distinct([
    for service in local.services : service.name
  ])

  target_group_names = {
    for name in local.service_names : name => distinct([
      for service in local.services :
      try(service.meta.alb_target_group_name, "default") if service.name == name
    ])
  }

  target_group_attachments = {
    for name in local.service_names : name => {
      for group_name in local.target_group_names[name] : group_name => {
        for service in local.services : service.id => {
          port              = tonumber(service.port)
          availability_zone = service.node_meta.availability_zone
          address           = service.address
        } if service.name == name && try(service.meta.alb_target_group_name, "default") == group_name
      }
    }
  }

  target_groups = {
    for name in local.service_names : name => {
      for group_name in local.target_group_names[name] : group_name => merge([
        for service in local.services : {
          deregistration_delay          = try(tonumber(service.meta.alb_deregistration_delay), null)
          preserve_client_ip            = try(tobool(service.meta.alb_preserve_client_ip), null)
          protocol_version              = try(service.meta.alb_protocol_version, "HTTP1")
          protocol                      = try(service.meta.alb_protocol, "HTTP")
          slow_start                    = try(service.meta.alb_slow_start, null)
          load_balancing_algorithm_type = try(service.meta.alb_load_balancing_algorithm_type, "round_robin")
          stickiness_enabled            = try(tobool(service.meta.alb_stickiness_enabled), false)
          stickiness_cookie_duration    = try(tonumber(service.meta.alb_stickiness_cookie_duration), null)
          stickiness_cookie_name        = try(service.meta.stickiness_cookie_name, null)
          stickiness_type               = try(service.meta.alb_stickiness_type, "lb_cookie")

          health_check_enabled             = try(tobool(service.meta.alb_health_check_enabled), null)
          health_check_healthy_threshold   = try(tonumber(service.meta.alb_health_check_healthy_threshold), null)
          health_check_interval            = try(tonumber(service.meta.alb_health_check_interval), null)
          health_check_matcher             = try(service.meta.alb_health_check_matcher, null)
          health_check_path                = try(service.meta.alb_health_check_path, null)
          health_check_port                = try(tonumber(service.meta.alb_health_check_port), null)
          health_check_protocol            = try(service.meta.alb_health_check_protocol, try(service.meta.alb_protocol, "HTTP"))
          health_check_timeout             = try(tonumber(service.meta.alb_health_check_timeout), null)
          health_check_unhealthy_threshold = try(tonumber(service.meta.alb_health_check_unhealthy_threshold), null)

          target_group_weight = try(tonumber(service.meta.alb_target_group_weight), null)
        } if service.name == name && try(service.meta.alb_target_group_name, "default") == group_name
      ]...)
    }
  }

  listener_rules = {
    for name in local.service_names : name => merge([
      for service in local.services : {
        authenticate_cognito = try(jsondecode(service.meta.authenticate_cognito), null)
        authenticate_oidc    = try(jsondecode(service.meta.authenticate_oidc), null)
        host_headers         = try(compact(distinct(jsondecode(service.meta.alb_host_headers))), [])
        http_headers         = try(jsondecode(service.meta.alb_http_headers), [])
        http_request_methods = try(compact(distinct(jsondecode(service.meta.alb_http_request_methods))), [])
        path_patterns        = try(compact(distinct(jsondecode(service.meta.alb_path_patterns))), [])
        priority             = try(tonumber(service.meta.alb_priority), null)
        query_strings        = try(jsondecode(service.meta.alb_query_strings), [])
        source_ips           = try(compact(distinct(jsondecode(service.meta.alb_source_ips))), [])
      } if service.name == name
    ]...)
  }

  values = {
    for name in local.service_names : name => merge(
      local.listener_rules[name],
      {
        target_groups = {
          for group_name in local.target_group_names[name] : group_name => merge(local.target_groups[name][group_name], {
            attachments = local.target_group_attachments[name][group_name]
          })
        }
      }
    )
  }

  # debug = local.rules
}

module "listener_rule" {
  source = "./modules/listener-rule"

  for_each = local.values

  name                 = each.key
  target_groups        = each.value.target_groups
  host_headers         = each.value.host_headers
  http_headers         = each.value.http_headers
  http_request_methods = each.value.http_request_methods
  path_patterns        = each.value.path_patterns
  query_strings        = each.value.query_strings
  source_ips           = each.value.source_ips
  priority             = each.value.priority

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
