output "ecr_repository_url" { value = module.ecr.repository_url }
output "ecr_repository_arn" { value = module.ecr.repository_arn }

# ── GitHub OIDC Role ARNs ──────────────────────────────────────────────────────
# Paste these into GitHub → Settings → Secrets and variables → Actions → Variables
# after running terraform apply in this environment.

output "github_ecr_push_role_arn" {
  description = "Paste as SHARED_ECR_PUSH_ROLE_ARN in GitHub repository variables"
  value       = module.github_oidc.ecr_push_role_arn
}

output "github_dev_deploy_role_arn" {
  description = "Paste as DEV_DEPLOY_ROLE_ARN in GitHub repository variables"
  value       = module.github_oidc.dev_deploy_role_arn
}

output "github_test_deploy_role_arn" {
  description = "Paste as TEST_DEPLOY_ROLE_ARN in GitHub repository variables"
  value       = module.github_oidc.test_deploy_role_arn
}

output "github_prod_deploy_role_arn" {
  description = "Paste as PROD_DEPLOY_ROLE_ARN in GitHub repository variables"
  value       = module.github_oidc.prod_deploy_role_arn
}
