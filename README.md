<!-- BEGIN_TF_DOCS -->
# terraform-aws-alb-nia

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2.0, < 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 4.34.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.2.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_listener_rule"></a> [listener\_rule](#module\_listener\_rule) | ./modules/listener-rule | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_listener_arn"></a> [listener\_arn](#input\_listener\_arn) | Listener ARN on Application Load Balancer. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS Region | `string` | n/a | yes |
| <a name="input_services"></a> [services](#input\_services) | Consul services monitored by Consul-Terraform-Sync | <pre>map(<br>    object({<br>      id        = string<br>      name      = string<br>      kind      = string<br>      address   = string<br>      port      = number<br>      meta      = map(string)<br>      tags      = list(string)<br>      namespace = string<br>      status    = string<br><br>      node                  = string<br>      node_id               = string<br>      node_address          = string<br>      node_datacenter       = string<br>      node_tagged_addresses = map(string)<br>      node_meta             = map(string)<br><br>      cts_user_defined_meta = map(string)<br>    })<br>  )</pre> | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID to attach a target group for Consul ingress gateway. | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->