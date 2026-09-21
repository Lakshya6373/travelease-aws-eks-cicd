terraform {
  required_version = ">= 1.11"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  backend "s3" {
    bucket       = "travelease-tfstate-892978057052"
    key          = "shared/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" { region = "ap-south-1" }

# Fetch the current AWS account ID — used by github-oidc module to scope EKS ARNs
data "aws_caller_identity" "current" {}

# ── Shared ECR Repository ─────────────────────────────────────────────────────
# One registry per AWS account, shared across dev/test/prod environments.
# Images are tagged by git SHA; the same image is promoted through environments.

module "ecr" {
  source          = "../../modules/ecr"
  repository_name = "travelease"
}

# ── GitHub OIDC Roles ─────────────────────────────────────────────────────────
# Creates the GitHub OIDC identity provider and four least-privilege IAM roles:
#   1. travelease-github-ecr-push   — push images to ECR (used by build job)
#   2. travelease-github-dev-deploy — describe dev EKS cluster (used by deploy-dev job)
#   3. travelease-github-test-deploy — describe test EKS cluster (used by deploy-test job)
#   4. travelease-github-prod-deploy — describe prod EKS cluster (used by deploy-prod job)
#
# After applying, run:
#   terraform output github_oidc
# and paste the role ARNs into GitHub repository variables.

module "github_oidc" {
  source             = "../../modules/github-oidc"
  github_repo        = "Lakshya6373/travelease-aws-eks-cicd"
  ecr_repository_arn = module.ecr.repository_arn
  aws_account_id     = data.aws_caller_identity.current.account_id
  aws_region         = "ap-south-1"
}
