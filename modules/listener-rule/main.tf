variable "name" {
  description = "Service name."
  type        = string
}

variable "target_groups" {
  description = "aws_lb_target_group_attachment arguments"
  type = map(object({
    attachments = map(object({
      address           = string
      availability_zone = string
      port              = number
    }))

    deregistration_delay          = any
    preserve_client_ip            = any
    protocol_version              = any
    protocol                      = any
    slow_start                    = any
    load_balancing_algorithm_type = any
    stickiness_enabled            = any
    stickiness_cookie_duration    = any
    stickiness_cookie_name        = any
    stickiness_type               = any

    health_check_enabled             = any
    health_check_healthy_threshold   = any
    health_check_interval            = any
    health_check_matcher             = any
    health_check_path                = any
    health_check_timeout             = any
    health_check_unhealthy_threshold = any

    target_group_weight = any
  }))
}

locals {
  single = length(values(var.target_groups)) == 1
}

# variable "target_groups" {
#   description = "aws_lb_target_group_attachment arguments"
#   type        = list(object({
#     address           = string
#     availability_zone = string
#     port              = number
#   }))
# }

variable "host_headers" {
  description = "A list of host header patterns to match. The maximum size of each pattern is 128 characters. Comparison is case insensitive. Wildcard characters supported: * (matches 0 or more characters) and ? (matches exactly 1 character). Only one pattern needs to match for the condition to be satisfied."
  type        = list(string)
  default     = []
}

variable "http_headers" {
  description = "HTTP headers to match."
  type = list(object({
    http_header_name = string
    values           = list(string)
  }))
  default = []
}

variable "http_request_methods" {
  description = "A list of HTTP request methods or verbs to match. Maximum size is 40 characters. Only allowed characters are A-Z, hyphen (-) and underscore (_). Comparison is case sensitive. Wildcards are not supported. Only one needs to match for the condition to be satisfied. AWS recommends that GET and HEAD requests are routed in the same way because the response to a HEAD request may be cached."
  type        = list(string)
  default     = []
}

variable "path_patterns" {
  description = "A list of path patterns to match against the request URL. Maximum size of each pattern is 128 characters. Comparison is case sensitive. Wildcard characters supported: * (matches 0 or more characters) and ? (matches exactly 1 character). Only one pattern needs to match for the condition to be satisfied. Path pattern is compared only to the path of the URL, not to its query string. To compare against the query string, use a query_string condition."
  type        = list(string)
  default     = []
}

variable "listener_arn" {
  description = "The ARN of the listener to which to attach the rule."
  type        = string
}

variable "vpc_id" {
  description = "Identifier of the VPC in which to create the target group."
  type        = string
}

variable "priority" {
  type        = number
  default     = null
  description = "Priority of listener rule between 1 to 50000"
  # validation {
  #   condition     = var.listener_rule_priority > 0 && var.listener_rule_priority < 50000
  #   error_message = "The priority of listener rule must between 1 to 50000."
  # }
}

module "target_group" {
  source = "../target-group"

  for_each = var.target_groups

  name         = each.key
  service_name = var.name

  attachments = each.value.attachments

  deregistration_delay          = each.value.deregistration_delay
  load_balancing_algorithm_type = each.value.load_balancing_algorithm_type
  preserve_client_ip            = each.value.preserve_client_ip
  protocol_version              = each.value.protocol_version
  protocol                      = each.value.protocol
  slow_start                    = each.value.slow_start
  stickiness_enabled            = local.single ? each.value.stickiness_enabled : false
  stickiness_cookie_duration    = each.value.stickiness_cookie_duration
  stickiness_cookie_name        = each.value.stickiness_cookie_name
  stickiness_type               = each.value.stickiness_type

  health_check_enabled             = each.value.health_check_enabled
  health_check_healthy_threshold   = each.value.health_check_healthy_threshold
  health_check_interval            = each.value.health_check_interval
  health_check_matcher             = each.value.health_check_matcher
  health_check_path                = each.value.health_check_path
  health_check_timeout             = each.value.health_check_timeout
  health_check_unhealthy_threshold = each.value.health_check_unhealthy_threshold

  target_group_weight = each.value.target_group_weight

  vpc_id = var.vpc_id
}

resource "aws_lb_listener_rule" "rule" {
  listener_arn = var.listener_arn
  priority     = var.priority

  action {
    type             = "forward"
    target_group_arn = local.single ? module.target_group[keys(module.target_group)[0]].arn : null

    dynamic "forward" {
      for_each = local.single ? [] : [true]

      content {
        dynamic "target_group" {
          for_each = module.target_group

          content {
            arn    = target_group.value.arn
            weight = target_group.value.weight
          }
        }

        stickiness {
          enabled  = false
          duration = 600
        }
      }
    }
  }

  condition {
    dynamic "host_header" {
      for_each = length(var.host_headers) > 0 ? [true] : []

      content {
        values = var.host_headers
      }
    }

    dynamic "path_pattern" {
      for_each = length(var.path_patterns) > 0 ? [true] : []

      content {
        values = var.path_patterns
      }
    }

    dynamic "http_request_method" {
      for_each = length(var.http_request_methods) > 0 ? [true] : []

      content {
        values = var.http_request_methods
      }
    }

    dynamic "http_header" {
      for_each = var.http_headers

      content {
        http_header_name = http_header.value.http_header_name
        values           = http_header.value.values
      }
    }

    # dynamic "source_ip" {
    #   for_each = length(local.source_ips) > 0 ? [local.source_ips] : []
    #
    #   content {
    #     values = source_ip.value
    #   }
    # }

    # dynamic "query_string" {
    #   for_each = local.query_strings
    #   content {
    #     key   = split(",", query_string.value).0
    #     value = split(",", query_string.value).1
    #   }
    # }
  }

  lifecycle {
    create_before_destroy = true
  }
}

