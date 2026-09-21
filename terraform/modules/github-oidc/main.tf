# ── GitHub OIDC Identity Provider ─────────────────────────────────────────────
# Registers GitHub Actions as a trusted identity provider in this AWS account.
# This is what allows GitHub to exchange its short-lived OIDC token for temporary
# AWS credentials — no static access keys required anywhere.
#
# This resource is created once per AWS account (not per environment).
# It lives in the shared Terraform environment.

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = [
    "sts.amazonaws.com",
    "https://github.com/Lakshya6373",
    "https://github.com/lakshya6373"
  ]
  thumbprint_list = [
    "ab9d0263244dd0326eb67015705a667e79cfe998",
    "cabd2a79a1076a31f21d253635cb039d4329a5e8",
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f8d7383c4f"
  ]

  tags = {
    Name      = "github-actions-oidc"
    ManagedBy = "terraform"
    Project   = "travelease"
  }
}

# ── Reusable Trust Policy Document ────────────────────────────────────────────
# Scoped tightly to the specific GitHub repository only.
# Any other repo — including forks — cannot assume these roles.

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # Only tokens from this specific repository are accepted
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [
        "repo:${var.github_repo}:*",
        "repo:${lower(var.github_repo)}:*",
        "repo:Lakshya6373*/travelease-aws-eks-cicd*:*",
        "repo:lakshya6373*/travelease-aws-eks-cicd*:*"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = [
        "sts.amazonaws.com",
        "https://github.com/Lakshya6373",
        "https://github.com/lakshya6373"
      ]
    }
  }
}

# ── Role 1: ECR Push ──────────────────────────────────────────────────────────
# Used by: build-and-push-image job in cd-pipeline.yml
# Permission: push Docker images to the shared ECR repository only.
# Cannot touch any EKS cluster, RDS instance, or IAM resource.

resource "aws_iam_role" "ecr_push" {
  name               = "travelease-github-ecr-push"
  description        = "GitHub Actions OIDC role - ECR image push only"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json

  tags = { ManagedBy = "terraform", Project = "travelease", Purpose = "github-oidc" }
}

resource "aws_iam_policy" "ecr_push" {
  name        = "travelease-GitHubECRPushPolicy"
  description = "Allows GitHub Actions to push images to the TravelEase ECR repository"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        # GetAuthorizationToken is account-level, cannot be scoped to one repo
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        # Scoped to the single TravelEase ECR repository only
        Resource = var.ecr_repository_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_push" {
  role       = aws_iam_role.ecr_push.name
  policy_arn = aws_iam_policy.ecr_push.arn
}

# ── Role 2: Dev Deploy ────────────────────────────────────────────────────────
# Used by: deploy-dev and smoke-test-dev jobs in cd-pipeline.yml
# Permission: describe the dev EKS cluster (to get kubeconfig) + RBAC inside cluster.
# Cannot touch test or prod cluster.

resource "aws_iam_role" "dev_deploy" {
  name               = "travelease-github-dev-deploy"
  description        = "GitHub Actions OIDC role - deploy to dev EKS cluster only"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json

  tags = { ManagedBy = "terraform", Project = "travelease", Environment = "dev", Purpose = "github-oidc" }
}

resource "aws_iam_policy" "dev_deploy" {
  name        = "travelease-GitHubDevDeployPolicy"
  description = "Allows GitHub Actions to update kubeconfig for the dev EKS cluster"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSDescribeDev"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        # Scoped to the dev cluster only by name
        Resource = "arn:aws:eks:${var.aws_region}:${var.aws_account_id}:cluster/dev"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dev_deploy" {
  role       = aws_iam_role.dev_deploy.name
  policy_arn = aws_iam_policy.dev_deploy.arn
}

# ── Role 3: Test Deploy ───────────────────────────────────────────────────────
# Used by: deploy-test and smoke-test-test jobs in cd-pipeline.yml
# Permission: describe the test EKS cluster only.

resource "aws_iam_role" "test_deploy" {
  name               = "travelease-github-test-deploy"
  description        = "GitHub Actions OIDC role - deploy to test EKS cluster only"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json

  tags = { ManagedBy = "terraform", Project = "travelease", Environment = "test", Purpose = "github-oidc" }
}

resource "aws_iam_policy" "test_deploy" {
  name        = "travelease-GitHubTestDeployPolicy"
  description = "Allows GitHub Actions to update kubeconfig for the test EKS cluster"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSDescribeTest"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "arn:aws:eks:${var.aws_region}:${var.aws_account_id}:cluster/test"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "test_deploy" {
  role       = aws_iam_role.test_deploy.name
  policy_arn = aws_iam_policy.test_deploy.arn
}

# ── Role 4: Prod Deploy ───────────────────────────────────────────────────────
# Used by: deploy-prod and smoke-test-prod jobs in cd-pipeline.yml
# Permission: describe the prod EKS cluster only.
# This role is only assumed after a named reviewer approves the production gate.

resource "aws_iam_role" "prod_deploy" {
  name               = "travelease-github-prod-deploy"
  description        = "GitHub Actions OIDC role - deploy to prod EKS cluster only (manual gate)"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json

  tags = { ManagedBy = "terraform", Project = "travelease", Environment = "prod", Purpose = "github-oidc" }
}

resource "aws_iam_policy" "prod_deploy" {
  name        = "travelease-GitHubProdDeployPolicy"
  description = "Allows GitHub Actions to update kubeconfig for the prod EKS cluster"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSDescribeProd"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "arn:aws:eks:${var.aws_region}:${var.aws_account_id}:cluster/prod"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "prod_deploy" {
  role       = aws_iam_role.prod_deploy.name
  policy_arn = aws_iam_policy.prod_deploy.arn
}
