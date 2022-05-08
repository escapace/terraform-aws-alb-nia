variable "name" {
  description = "Name of the target group."
  type        = string
}

variable "attachments" {
  description = "aws_lb_target_group_attachment arguments"
  type        = list(object({
    address           = string
    availability_zone = string
    port              = number
  }))
}

variable "deregistration_delay" {
  description = "Amount time for Elastic Load Balancing to wait before changing the state of a deregistering target from draining to unused. The range is 0-3600 seconds. The default value is 300 seconds."
  type        = number
  default     = null
}
  
variable "load_balancing_algorithm_type" {
  description = "Determines how the load balancer selects targets when routing requests. Only applicable for Application Load Balancer Target Groups. The value is round_robin or least_outstanding_requests. The default is round_robin."
  type        = string

  validation {
    condition     = contains(["round_robin", "least_outstanding_requests"], var.load_balancing_algorithm_type)
    error_message = "The load_balancing_algorithm_type value must be either \"round_robin\" or \"least_outstanding_requests\"."
  }
}

variable "preserve_client_ip" {
  description = "Whether client IP preservation is enabled."
  type        = bool
  default     = null
}

variable "protocol_version" {
  description = "Specify HTTP2 to send requests to targets using HTTP/2. The default is HTTP1, which sends requests to targets using HTTP/1.1."
  type        = string

  validation {
    condition     = contains(["HTTP1", "HTTP2"], var.protocol_version)
    error_message = "The protocol_version value must be either \"HTTP1\" or \"HTTP2\"."
  }
}

variable "protocol" {
  description = "Protocol to use for routing traffic to the targets. Should be one of HTTP or HTTPS."
  type = string

  validation {
    condition     = contains(["HTTP", "HTTPS"], var.protocol)
    error_message = "The protocol value must be either \"HTTP\" or \"HTTPS\"."
  }
}

variable "slow_start" {
  description = "Amount time for targets to warm up before the load balancer sends them a full share of requests. The range is 30-900 seconds or 0 to disable. The default value is 0 seconds."
  type        = number
  default     = null
}

variable "stickiness_enabled" {
  description = "Boolean to enable / disable stickiness. Default is true."
  type        = bool
  default     = true
}

variable "stickiness_cookie_duration" {
  description = "Only used when the type is lb_cookie. The time period, in seconds, during which requests from a client should be routed to the same target. After this time period expires, the load balancer-generated cookie is considered stale. The range is 1 second to 1 week (604800 seconds). The default value is 1 day (86400 seconds)."
  type        = number
  default     = null
}

variable "stickiness_cookie_name" {
  description = "Name of the application based cookie. AWSALB, AWSALBAPP, and AWSALBTG prefixes are reserved and cannot be used. Only needed when type is app_cookie."
  type        = string
  default     = null
}

variable "stickiness_type" {
  description = "The type of sticky sessions. The only current possible values are lb_cookie, app_cookie for ALBs."
  type        = string
  default     = "lb_cookie"

  validation {
    condition     = contains(["lb_cookie", "app_cookie"], var.stickiness_type)
    error_message = "The stickiness_type value must be either \"lb_cookie\" or \"app_cookie\"."
  }
}

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

variable "health_check_enabled" {
  type        = bool
  default     = true
  description = "Whether health checks are enabled."
}

variable "health_check_healthy_threshold" {
  type        = number
  description = "Number of consecutive health checks successes required before considering an unhealthy target healthy. Defaults to 3."
  default     = 3
}

variable "health_check_interval" {
  type        = number
  description = "Approximate amount of time, in seconds, between health checks of an individual target. Minimum value 5 seconds, Maximum value 300 seconds. For lambda target groups, it needs to be greater as the timeout of the underlying lambda. Default 30 seconds."
  default     = 30
}

variable "health_check_matcher" {
  type        = string
  description = "Response codes to use when checking for a healthy responses from a target."
  default     = "200-299"
}

variable "health_check_path" {
  type        = string
  description = "Destination for the health check request."
  default     = "/"
}

variable "health_check_timeout" {
  type        = number
  description = "Amount of time, in seconds, during which no response means a failed health check."
  default     = 5
}

variable "health_check_unhealthy_threshold" {
  type        = number
  description = "Number of consecutive health check failures required before considering the target unhealthy."
  default     = 3
}

resource "aws_lb_target_group" "group" {
  name_prefix = substr(sha256(var.name), -6, 0)

  deregistration_delay          = var.deregistration_delay
  load_balancing_algorithm_type = var.load_balancing_algorithm_type
  port                          = var.protocol == "HTTP" ? 80 : 443
  preserve_client_ip            = var.preserve_client_ip
  protocol                      = var.protocol
  protocol_version              = var.protocol_version
  slow_start                    = var.slow_start
  target_type                   = "ip"
  vpc_id                        = var.vpc_id

  stickiness {
    enabled         = var.stickiness_enabled
    type            = var.stickiness_enabled ? var.stickiness_type : null
    cookie_duration = (var.stickiness_enabled && var.stickiness_type == "lb_cookie") ? var.stickiness_cookie_duration : null
    cookie_name     = (var.stickiness_enabled && var.stickiness_type == "app_cookie") ? var.stickiness_cookie_name : null
  }

  health_check {
    enabled             = var.health_check_enabled
    healthy_threshold   = var.health_check_healthy_threshold
    interval            = var.health_check_interval
    matcher             = var.health_check_matcher
    protocol            = var.protocol
    path                = var.health_check_path
    timeout             = var.health_check_timeout
    unhealthy_threshold = var.health_check_unhealthy_threshold
  }

  tags = {
    Name = var.name
  }
}

resource "aws_lb_target_group_attachment" "attachment" {
  count = length(var.attachments)

  target_group_arn  = aws_lb_target_group.group.arn
  target_id         = var.attachments[count.index].address
  port              = var.attachments[count.index].port
  availability_zone = var.attachments[count.index].availability_zone
}

resource "aws_lb_listener_rule" "rule" {
  listener_arn = var.listener_arn
  priority     = var.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.group.arn
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

}

