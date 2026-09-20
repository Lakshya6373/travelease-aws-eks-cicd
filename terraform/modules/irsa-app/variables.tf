variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the EKS cluster OIDC provider"
}

variable "oidc_provider_url" {
  type        = string
  description = "URL of the EKS cluster OIDC provider (with https://)"
}

variable "environment_name" {
  type        = string
  description = "Short environment label: dev | test | prod"
}

variable "secret_arn" {
  type        = string
  description = "ARN of the Secrets Manager secret the app is allowed to read"
}

variable "bedrock_region" {
  type        = string
  default     = "ap-south-1"
  description = "Region for Bedrock invocations (uses cross-region inference profile)"
}

variable "app_namespace" {
  type        = string
  default     = "travelease"
  description = "Kubernetes namespace where the app service account lives"
}

variable "app_service_account" {
  type        = string
  default     = "travelease-app"
  description = "Kubernetes service account name for the app pod"
}
