output "web_acl_arn" {
  description = "WAF Web ACL ARN — empty string when enable_waf=false"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : ""
}
