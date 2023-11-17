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

variable "services_overrides" {
  description = "Consul services monitored by Consul-Terraform-Sync"
  type        = list(any)
  default     = []
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

  services_overrides_names = distinct([
    for service in var.services_overrides : service.name
  ])

  services_overrides = { for service_name in local.services_overrides_names : service_name => merge([for service in var.services_overrides : service if service.name == service_name]...) }

  services = distinct([
    for key, service in var.services : merge(service, { key = key })
    if !contains(local.exclude_kind, service.kind)
    && service.status == "passing"
    && try(local.services_overrides[service.name].enabled, tobool(service.meta.alb_enabled), false)
  ])

  service_names = distinct([
    for service in local.services : service.name
  ])

  target_group_names = {
    for name in local.service_names : name => distinct([
      for service in local.services :
      try(local.services_overrides[service.name].target_group_name, service.meta.alb_target_group_name, "default") if service.name == name
    ])
  }

  target_group_attachments = {
    for name in local.service_names : name => {
      for group_name in local.target_group_names[name] : group_name => [
        for option in [
          {
            for service in local.services : service.key => {
              address           = service.address
              availability_zone = service.node_meta.availability_zone
              port              = tonumber(service.port)
            } if service.name == name &&
            try(local.services_overrides[service.name].target_group_name, service.meta.alb_target_group_name, "default") == group_name
            && try(tonumber(service.port) == local.services_overrides[service.name].port, local.services_overrides[service.name].port > -1, true)
          },
          {
            for attachment in distinct([for service in local.services : {
              address           = service.address
              availability_zone = service.node_meta.availability_zone
              port              = try(local.services_overrides[service.name].port, tonumber(service.port))
              } if service.name == name &&
            try(local.services_overrides[service.name].target_group_name, service.meta.alb_target_group_name, "default") == group_name]) : uuidv5("oid", join(" ", [attachment.address, attachment.availability_zone, attachment.port])) => attachment
          }
      ] : option if length(keys(option)) != 0][0]
    }
  }

  target_groups = {
    for name in local.service_names : name => {
      for group_name in local.target_group_names[name] : group_name => merge([
        for service in local.services : {
          deregistration_delay          = try(local.services_overrides[service.name].deregistration_delay, tonumber(service.meta.alb_deregistration_delay), null)
          preserve_client_ip            = try(local.services_overrides[service.name].preserve_client_ip, tobool(service.meta.alb_preserve_client_ip), null)
          protocol_version              = try(local.services_overrides[service.name].protocol_version, service.meta.alb_protocol_version, "HTTP1")
          protocol                      = try(local.services_overrides[service.name].protocol, service.meta.alb_protocol, "HTTP")
          slow_start                    = try(local.services_overrides[service.name].slow_start, tonumber(service.meta.alb_slow_start), null)
          load_balancing_algorithm_type = try(local.services_overrides[service.name].load_balancing_algorithm_type, service.meta.alb_load_balancing_algorithm_type, "round_robin")
          stickiness_enabled            = try(local.services_overrides[service.name].stickiness_enabled, tobool(service.meta.alb_stickiness_enabled), false)
          stickiness_cookie_duration    = try(local.services_overrides[service.name].stickiness_cookie_duration, tonumber(service.meta.alb_stickiness_cookie_duration), null)
          stickiness_cookie_name        = try(local.services_overrides[service.name].stickiness_cookie_name, service.meta.alb_stickiness_cookie_name, null)
          stickiness_type               = try(local.services_overrides[service.name].stickiness_type, service.meta.alb_stickiness_type, "lb_cookie")

          health_check_enabled             = try(local.services_overrides[service.name].health_check_enabled, tobool(service.meta.alb_health_check_enabled), null)
          health_check_healthy_threshold   = try(local.services_overrides[service.name].health_check_healthy_threshold, tonumber(service.meta.alb_health_check_healthy_threshold), null)
          health_check_interval            = try(local.services_overrides[service.name].health_check_interval, tonumber(service.meta.alb_health_check_interval), null)
          health_check_matcher             = try(local.services_overrides[service.name].health_check_matcher, service.meta.alb_health_check_matcher, null)
          health_check_path                = try(local.services_overrides[service.name].health_check_path, service.meta.alb_health_check_path, null)
          health_check_port                = try(local.services_overrides[service.name].health_check_port, tonumber(service.meta.alb_health_check_port), null)
          health_check_protocol            = try(local.services_overrides[service.name].health_check_protocol, service.meta.alb_health_check_protocol, service.meta.alb_protocol, "HTTP")
          health_check_timeout             = try(local.services_overrides[service.name].health_check_timeout, tonumber(service.meta.alb_health_check_timeout), null)
          health_check_unhealthy_threshold = try(local.services_overrides[service.name].health_check_unhealthy_threshold, tonumber(service.meta.alb_health_check_unhealthy_threshold), null)

          target_group_weight = try(local.services_overrides[service.name].target_group_weight, tonumber(service.meta.alb_target_group_weight), null)
        } if service.name == name && try(local.services_overrides[service.name].target_group_name, service.meta.alb_target_group_name, "default") == group_name
      ]...)
    }
  }

  listener_rules = {
    for name in local.service_names : name => merge([
      for service in local.services : {
        authenticate_cognito = try(local.services_overrides[service.name].authenticate_cognito, jsondecode(service.meta.alb_authenticate_cognito), null)
        authenticate_oidc    = try(local.services_overrides[service.name].authenticate_oidc, jsondecode(service.meta.alb_authenticate_oidc), null)
        host_headers         = try(local.services_overrides[service.name].host_headers, compact(distinct(jsondecode(service.meta.alb_host_headers))), [])
        http_headers         = try(local.services_overrides[service.name].http_headers, jsondecode(service.meta.alb_http_headers), [])
        http_request_methods = try(local.services_overrides[service.name].http_request_methods, compact(distinct(jsondecode(service.meta.alb_http_request_methods))), [])
        path_patterns        = try(local.services_overrides[service.name].path_patterns, compact(distinct(jsondecode(service.meta.alb_path_patterns))), [])
        priority             = try(local.services_overrides[service.name].priority, tonumber(service.meta.alb_priority), null)
        query_strings        = try(local.services_overrides[service.name].query_strings, jsondecode(service.meta.alb_query_strings), [])
        source_ips           = try(local.services_overrides[service.name].source_ips, compact(distinct(jsondecode(service.meta.alb_source_ips))), [])
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
