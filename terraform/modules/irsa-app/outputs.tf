output "role_arn" {
  description = "ARN of the app IRSA role — annotate the service account with this"
  value       = aws_iam_role.app.arn
}

output "role_name" {
  description = "Name of the app IRSA role"
  value       = aws_iam_role.app.name
}
