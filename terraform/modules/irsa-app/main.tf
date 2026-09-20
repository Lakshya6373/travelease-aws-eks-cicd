# ── Trust Policy ──────────────────────────────────────────────────────────────
# Scoped tightly to the app's service account only (not ESO, not any wildcard)

data "aws_iam_policy_document" "app_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    # Only the app service account in the app namespace can assume this role
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.app_namespace}:${var.app_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# ── IAM Role ──────────────────────────────────────────────────────────────────

resource "aws_iam_role" "app" {
  name               = "${var.environment_name}-app-irsa"
  assume_role_policy = data.aws_iam_policy_document.app_assume_role.json

  tags = { Environment = var.environment_name, ManagedBy = "terraform" }
}

# ── Combined Permission Policy ────────────────────────────────────────────────
# Single policy granting both Bedrock invocation and Secrets Manager read.
# Scoped to least-privilege: specific model ARN + specific secret ARN.

resource "aws_iam_policy" "app" {
  name        = "${var.environment_name}-AppIRSAPolicy"
  description = "App pod IRSA: Bedrock (ap-south-1 cross-region) + SecretsManager read"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockInvoke"
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        # Allows invoking via APAC cross-region inference profile and foundation model
        Resource = [
          "arn:aws:bedrock:${var.bedrock_region}:*:inference-profile/apac.amazon.nova-micro-v1:0",
          "arn:aws:bedrock:*::foundation-model/amazon.nova-micro-v1:0"
        ]
      },
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        # Scoped to this environment's secret only — not "*"
        Resource = var.secret_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.app.arn
}
