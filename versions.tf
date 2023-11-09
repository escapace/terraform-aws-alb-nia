terraform {
  required_version = ">= 1.3.0, <= 1.6.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.24.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~>3.5.1"
    }
  }
}
