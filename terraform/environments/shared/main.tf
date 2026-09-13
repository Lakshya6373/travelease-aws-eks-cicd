terraform {
  required_version = ">= 1.11"
  required_providers {
    aws = { source = "hashicorp/aws"; version = "~> 5.60" }
    tls = { source = "hashicorp/tls"; version = "~> 4.0" }
  }
  backend "s3" {
    bucket       = "travelease-terraform-state-<YOUR-UNIQUE-SUFFIX>"
    key          = "shared/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" { region = "ap-south-1" }

module "ecr" {
  source          = "../../modules/ecr"
  repository_name = "travelease"
}
