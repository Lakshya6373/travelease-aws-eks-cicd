variable "github_repo" {
  type        = string
  description = "GitHub repository in owner/repo format. Only this repo can assume the OIDC roles."
  # Example: "Lakshya6373/travelease-aws-eks-cicd"
}

variable "ecr_repository_arn" {
  type        = string
  description = "ARN of the shared ECR repository. The ECR push role is scoped to this ARN only."
}

variable "aws_account_id" {
  type        = string
  description = "AWS account ID. Used to construct EKS cluster ARNs for least-privilege deploy policies."
}

variable "aws_region" {
  type        = string
  default     = "ap-south-1"
  description = "AWS region where EKS clusters are deployed."
}
