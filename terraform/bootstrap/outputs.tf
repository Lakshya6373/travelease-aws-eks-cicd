output "bucket_name" {
  description = "The name of the Terraform state S3 bucket."
  value       = aws_s3_bucket.state.id
}

output "bucket_arn" {
  description = "The ARN of the Terraform state S3 bucket."
  value       = aws_s3_bucket.state.arn
}
