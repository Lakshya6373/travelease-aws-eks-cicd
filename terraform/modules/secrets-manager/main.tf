resource "aws_secretsmanager_secret" "app" {
  name                    = "travelease/${var.environment_name}/app-secrets"
  description             = "TravelEase application secrets for ${var.environment_name}"
  recovery_window_in_days = var.environment_name == "prod" ? 7 : 0

  tags = { Environment = var.environment_name }
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    db_host     = var.db_host
    db_port     = tostring(var.db_port)
    db_name     = var.db_name
    db_user     = var.db_user
    db_password = var.db_password
    jwt_secret  = var.jwt_secret
  })
}
