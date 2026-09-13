data "aws_iam_policy_document" "bedrock_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    # This trust is on the APP service account, not ESO — separate IRSA per component
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:travelease:travelease-app"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bedrock" {
  name               = "${var.environment_name}-bedrock-irsa"
  assume_role_policy = data.aws_iam_policy_document.bedrock_assume_role.json
}

resource "aws_iam_policy" "bedrock" {
  name        = "${var.environment_name}-BedrockInvokePolicy"
  description = "Allow invoking Amazon Nova Micro in us-east-1 only"

  # NOTE: bedrock_region is us-east-1 even though all infra is in ap-south-1.
  # Nova Micro direct on-demand invocation isn't available in ap-south-1.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["bedrock:InvokeModel"]
      Resource = "arn:aws:bedrock:${var.bedrock_region}::foundation-model/amazon.nova-micro-v1:0"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bedrock" {
  role       = aws_iam_role.bedrock.name
  policy_arn = aws_iam_policy.bedrock.arn
}
