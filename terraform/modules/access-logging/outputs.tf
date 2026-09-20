output "logs_bucket_name" { value = aws_s3_bucket.access_logs.bucket }
output "glue_table_name" { value = aws_glue_catalog_table.alb_logs.name }
