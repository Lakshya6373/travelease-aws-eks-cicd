# ── GitHub OIDC Role ARNs ──────────────────────────────────────────────────────
# After running terraform apply in the shared environment, copy these outputs
# and paste them into GitHub → Settings → Secrets and variables → Actions → Variables.
#
# Variable name in GitHub    →   Output to copy
# ─────────────────────────────────────────────────
# SHARED_ECR_PUSH_ROLE_ARN   →   ecr_push_role_arn
# DEV_DEPLOY_ROLE_ARN        →   dev_deploy_role_arn
# TEST_DEPLOY_ROLE_ARN       →   test_deploy_role_arn
# PROD_DEPLOY_ROLE_ARN       →   prod_deploy_role_arn

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC identity provider created in this AWS account."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "ecr_push_role_arn" {
  description = "ARN of the ECR push role. Set as SHARED_ECR_PUSH_ROLE_ARN in GitHub repository variables."
  value       = aws_iam_role.ecr_push.arn
}

output "dev_deploy_role_arn" {
  description = "ARN of the dev deploy role. Set as DEV_DEPLOY_ROLE_ARN in GitHub repository variables."
  value       = aws_iam_role.dev_deploy.arn
}

output "test_deploy_role_arn" {
  description = "ARN of the test deploy role. Set as TEST_DEPLOY_ROLE_ARN in GitHub repository variables."
  value       = aws_iam_role.test_deploy.arn
}

output "prod_deploy_role_arn" {
  description = "ARN of the prod deploy role. Set as PROD_DEPLOY_ROLE_ARN in GitHub repository variables."
  value       = aws_iam_role.prod_deploy.arn
}
