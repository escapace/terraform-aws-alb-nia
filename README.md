<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_rule"></a> [rule](#module\_rule) | ./modules/rule | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_listener_arn"></a> [listener\_arn](#input\_listener\_arn) | Listener ARN on Application Load Balancer. | `string` | `"arn:aws:elasticloadbalancing:us-west-2:132022643098:listener/app/escapace-production-stack-alb/65e65ac19428ded6/ea61ffeb49fabce2"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region | `string` | n/a | yes |
| <a name="input_services"></a> [services](#input\_services) | Consul services monitored by Consul-Terraform-Sync | <pre>map(<br>    object({<br>      id        = string<br>      name      = string<br>      kind      = string<br>      address   = string<br>      port      = number<br>      meta      = map(string)<br>      tags      = list(string)<br>      namespace = string<br>      status    = string<br><br>      node                  = string<br>      node_id               = string<br>      node_address          = string<br>      node_datacenter       = string<br>      node_tagged_addresses = map(string)<br>      node_meta             = map(string)<br><br>      cts_user_defined_meta = map(string)<br>    })<br>  )</pre> | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID to attach a target group for Consul ingress gateway. | `string` | `"vpc-0ef0478362f09b969"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->