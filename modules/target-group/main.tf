variable "name" {
  description = "Name of the target group."
  type        = string
}

variable "service_name" {
  description = "Service name."
  type        = string
}

variable "target_group_weight" {
  description = "The target group weight."
  type        = number
  default     = null
}

variable "attachments" {
  description = "The \"aws_lb_target_group_attachment\" arguments."
  type = map(object({
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
  type        = string

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
  description = "Boolean to enable / disable stickiness. Default is false."
  type        = bool
  default     = false
}

variable "stickiness_cookie_duration" {
  description = "Only used when the type is lb_cookie. The time period, in seconds, during which requests from a client should be routed to the same target. After this time period expires, the load balancer-generated cookie is considered stale. The range is 1 second to 1 week (604800 seconds). The default value is 1 day (86400 seconds)."
  type        = number
  default     = null

  # validation {
  #   condition     = var.stickiness_cookie_duration >= 1 && var.stickiness_cookie_duration <= 604800
  #   error_message = "The stickiness_cookie_duration must between 1 to 604800."
  # }
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

variable "vpc_id" {
  description = "Identifier of the VPC in which to create the target group."
  type        = string
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


# health_check_port
# health_check_protocol

variable "health_check_port" {
  type        = number
  description = "Port to use to connect with the target. Valid values are either ports 1-65535, or traffic-port. Defaults to traffic-port."
  default     = null
}

variable "health_check_protocol" {
  type        = string
  description = "Protocol to use to connect with the target."
  default     = null
}

resource "random_string" "name_prefix" {
  keepers = {
    name         = var.name
    service_name = var.service_name

    vpc_id             = var.vpc_id
    stickiness_enabled = var.stickiness_enabled
    stickiness_type    = var.stickiness_type
  }

  length  = 6
  lower   = true
  number  = false
  special = false
  upper   = false

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  has_ipv4        = anytrue(flatten([for attachment in var.attachments : length(regexall("[.]", attachment.address)) > 0]))
  has_ipv6        = anytrue(flatten([for attachment in var.attachments : length(regexall("[:]", attachment.address)) > 0]))
  ip_address_type = local.has_ipv4 && local.has_ipv6 ? "mixed" : local.has_ipv4 ? "ipv4" : local.has_ipv6 ? "ipv6" : "none"
}

resource "aws_lb_target_group" "default" {
  name_prefix = random_string.name_prefix.result

  deregistration_delay          = var.deregistration_delay
  load_balancing_algorithm_type = var.load_balancing_algorithm_type
  port                          = var.protocol == "HTTP" ? 80 : 443
  preserve_client_ip            = var.preserve_client_ip
  protocol                      = var.protocol
  protocol_version              = var.protocol_version
  slow_start                    = var.slow_start
  target_type                   = "ip"
  ip_address_type               = local.ip_address_type
  vpc_id                        = var.vpc_id

  stickiness {
    enabled         = var.stickiness_enabled
    type            = var.stickiness_type
    cookie_duration = (var.stickiness_type == "lb_cookie") ? var.stickiness_cookie_duration : null
    cookie_name     = (var.stickiness_type == "app_cookie") ? var.stickiness_cookie_name : null
  }

  health_check {
    enabled             = var.health_check_enabled
    healthy_threshold   = var.health_check_healthy_threshold
    interval            = var.health_check_interval
    matcher             = var.health_check_matcher
    path                = var.health_check_path
    port                = var.health_check_port
    protocol            = var.health_check_protocol
    timeout             = var.health_check_timeout
    unhealthy_threshold = var.health_check_unhealthy_threshold
  }

  tags = {
    Name    = var.name
    Service = var.service_name
  }

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = local.ip_address_type == "ipv4" || local.ip_address_type == "ipv6"
      error_message = "target group ip address mismatch"
    }
  }
}

resource "aws_lb_target_group_attachment" "attachment" {
  for_each = var.attachments

  target_group_arn  = aws_lb_target_group.default.arn
  target_id         = each.value.address
  port              = each.value.port
  availability_zone = each.value.availability_zone

  lifecycle {
    create_before_destroy = true
  }
}

output "arn" {
  description = "ARN of the target group."
  value       = aws_lb_target_group.default.arn
}

output "weight" {
  description = "The target group weight."
  value       = var.target_group_weight
}
