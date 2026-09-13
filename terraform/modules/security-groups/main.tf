# ── ALB Security Group ────────────────────────────────────────────────────────

resource "aws_security_group" "alb" {
  name        = "${var.environment_name}-alb-sg"
  description = "ALB: allow HTTP/HTTPS from Internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment_name}-alb-sg" }
}

# ── Node Security Group ───────────────────────────────────────────────────────

resource "aws_security_group" "node" {
  name        = "${var.environment_name}-node-sg"
  description = "EKS nodes: accept traffic from ALB + intra-node"
  vpc_id      = var.vpc_id

  # Allow traffic from the ALB on the app port
  ingress {
    description              = "From ALB on app port"
    from_port                = var.app_port
    to_port                  = var.app_port
    protocol                 = "tcp"
    security_groups          = [aws_security_group.alb.id]
  }

  # Allow all traffic within the node SG (pod-to-pod communication)
  ingress {
    description = "Intra-node / pod-to-pod"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment_name}-node-sg" }
}

# ── RDS Security Group ────────────────────────────────────────────────────────

resource "aws_security_group" "rds" {
  name        = "${var.environment_name}-rds-sg"
  description = "RDS: accept PostgreSQL connections from nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description              = "PostgreSQL from EKS nodes"
    from_port                = 5432
    to_port                  = 5432
    protocol                 = "tcp"
    security_groups          = [aws_security_group.node.id]
  }

  # No egress needed for RDS
  tags = { Name = "${var.environment_name}-rds-sg" }
}
