terraform {
  required_version = ">= 1.11"
  required_providers {
    aws = { source = "hashicorp/aws"; version = "~> 5.60" }
    tls = { source = "hashicorp/tls"; version = "~> 4.0" }
  }
  backend "s3" {
    bucket       = "travelease-terraform-state-<YOUR-UNIQUE-SUFFIX>"
    key          = "prod/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" { region = var.region }

locals {
  env  = var.environment_name
  tags = { Environment = local.env, Project = "travelease", ManagedBy = "terraform" }
}

module "vpc" {
  source                = "../../modules/vpc"
  environment_name      = local.env
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  availability_zones    = var.availability_zones
  tags                  = local.tags
}

module "security_groups" {
  source           = "../../modules/security-groups"
  vpc_id           = module.vpc.vpc_id
  environment_name = local.env
}

module "eks" {
  source               = "../../modules/eks"
  cluster_name         = "travelease-${local.env}"
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  node_instance_types  = var.node_instance_types
  node_min_size        = var.node_min_size
  node_max_size        = var.node_max_size
  node_desired_size    = var.node_desired_size
  environment_name     = local.env
}

module "rds" {
  source                  = "../../modules/rds"
  environment_name        = local.env
  private_subnet_ids      = module.vpc.private_subnet_ids
  rds_security_group_id   = module.security_groups.rds_sg_id
  instance_class          = var.rds_instance_class
  db_name                 = "travelease"
  master_username         = var.db_master_username
  master_password         = var.db_master_password
  backup_retention_period = var.backup_retention_period
}

module "waf" {
  source           = "../../modules/waf"
  environment_name = local.env
  enable_waf       = var.enable_waf
}

module "access_logging" {
  source           = "../../modules/access-logging"
  environment_name = local.env
  region           = var.region
}

module "secrets_manager" {
  source           = "../../modules/secrets-manager"
  environment_name = local.env
  db_host          = module.rds.db_endpoint
  db_port          = module.rds.db_port
  db_name          = module.rds.db_name
  db_user          = var.db_master_username
  db_password      = var.db_master_password
  jwt_secret       = var.jwt_secret
}

module "irsa_alb_controller" {
  source             = "../../modules/irsa-alb-controller"
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.oidc_provider_url
  environment_name   = local.env
}

module "irsa_external_secrets" {
  source             = "../../modules/irsa-external-secrets"
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.oidc_provider_url
  secret_arn         = module.secrets_manager.secret_arn
  environment_name   = local.env
}

module "irsa_bedrock" {
  source             = "../../modules/irsa-bedrock"
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.oidc_provider_url
  bedrock_region     = "us-east-1"
  environment_name   = local.env
}
