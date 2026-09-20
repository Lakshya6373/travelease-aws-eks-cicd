resource "aws_db_subnet_group" "main" {
  name       = "${var.environment_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${var.environment_name}-db-subnet-group" }
}

resource "aws_db_instance" "main" {
  identifier              = "${var.environment_name}-postgres"
  engine                  = "postgres"
  engine_version          = var.engine_version
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  storage_type            = "gp3"
  storage_encrypted       = true
  db_name                 = var.db_name
  username                = var.master_username
  password                = var.master_password
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [var.rds_security_group_id]
  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.environment_name == "prod" ? true : false

  # Snapshot on final destroy only in prod
  skip_final_snapshot       = var.environment_name == "prod" ? false : true
  final_snapshot_identifier = var.environment_name == "prod" ? "${var.environment_name}-postgres-final-snapshot" : null

  apply_immediately = true

  tags = { Environment = var.environment_name }
}
