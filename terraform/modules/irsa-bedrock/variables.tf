variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider_url" {
  type = string
}

variable "bedrock_region" {
  type    = string
  default = "us-east-1"
}

variable "environment_name" {
  type = string
}

