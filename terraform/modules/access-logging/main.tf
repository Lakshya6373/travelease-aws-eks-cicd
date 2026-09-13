data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── S3 Bucket for ALB Access Logs ────────────────────────────────────────────

resource "aws_s3_bucket" "access_logs" {
  bucket        = "travelease-${var.environment_name}-alb-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = { Environment = var.environment_name }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Grant ALB service account write access — required by AWS docs
resource "aws_s3_bucket_policy" "alb_write" {
  bucket = aws_s3_bucket.access_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowALBAccessLogs"
      Effect = "Allow"
      # AWS-managed ELB service account for ap-south-1 (see AWS ALB access logging docs)
      Principal = { AWS = "arn:aws:iam::718504428378:root" }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.access_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    }]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    filter { prefix = "" }
    expiration { days = 14 }
  }
}

# ── Glue Catalog — ALB Log Schema (for Athena / Grafana Athena datasource) ───

resource "aws_glue_catalog_database" "alb_logs" {
  name = "travelease_${var.environment_name}_alb_logs"
}

resource "aws_glue_catalog_table" "alb_logs" {
  database_name = aws_glue_catalog_database.alb_logs.name
  name          = "alb_access_logs"

  table_type = "EXTERNAL_TABLE"

  parameters = {
    "serialization.format" = "1"
    "EXTERNAL"             = "TRUE"
    "skip.header.line.count" = "0"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.access_logs.bucket}/AWSLogs/${data.aws_caller_identity.current.account_id}/elasticloadbalancing/${var.region}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.RegexSerDe"
      parameters = {
        "serialization.format" = "1"
        "input.regex"          = "([^ ]*) ([^ ]*) ([^ ]*) ([^ ]*):([0-9]*) ([^ ]*)[:-]([0-9]*) ([-.0-9]*) ([-.0-9]*) ([-.0-9]*) (|[-0-9]*) (-|[-0-9]*) ([-0-9]*) ([-0-9]*) \"([^ ]*) ([^ ]*) (- |[^ ]*)\" \"([^\"]*)\" ([A-Z0-9-_]+) ([A-Za-z0-9.-]*) ([^ ]*) \"([^\"]*)\" \"([^\"]*)\" \"([^\"]*)\" ([-.0-9]*) ([^ ]*) \"([^\"]*)\" \"([^\"]*)\" \"([^ ]*)\" \"([^\\s]+?)\" \"([^\\s]+)\" \"([^ ]*)\" \"([^ ]*)\"$"
      }
    }

    # ALB access log columns per AWS documentation
    columns {
      name = "type"
      type = "string"
    }
    columns {
      name = "time"
      type = "string"
    }
    columns {
      name = "elb"
      type = "string"
    }
    columns {
      name = "client_ip"
      type = "string"
    }
    columns {
      name = "client_port"
      type = "int"
    }
    columns {
      name = "target_ip"
      type = "string"
    }
    columns {
      name = "target_port"
      type = "int"
    }
    columns {
      name = "request_processing_time"
      type = "double"
    }
    columns {
      name = "target_processing_time"
      type = "double"
    }
    columns {
      name = "response_processing_time"
      type = "double"
    }
    columns {
      name = "elb_status_code"
      type = "int"
    }
    columns {
      name = "target_status_code"
      type = "string"
    }
    columns {
      name = "received_bytes"
      type = "bigint"
    }
    columns {
      name = "sent_bytes"
      type = "bigint"
    }
    columns {
      name = "request_verb"
      type = "string"
    }
    columns {
      name = "request_url"
      type = "string"
    }
    columns {
      name = "request_proto"
      type = "string"
    }
    columns {
      name = "user_agent"
      type = "string"
    }
    columns {
      name = "ssl_cipher"
      type = "string"
    }
    columns {
      name = "ssl_protocol"
      type = "string"
    }
  }
}
