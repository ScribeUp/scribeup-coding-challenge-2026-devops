# Production Postgres. Separate state from ../core so a mistake there can't touch
# the database. LocalStack doesn't run RDS, so locally this directory is only
# validated, never planned or applied.

resource "aws_db_subnet_group" "main" {
  name       = "scan-${var.environment}"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "db" {
  name   = "scan-db-${var.environment}"
  vpc_id = var.vpc_id

  ingress {
    description     = "Postgres from the web and worker instances"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.app_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "main" {
  identifier                   = "scan-${var.environment}"
  engine                       = "postgres"
  engine_version               = "16"
  instance_class               = "db.m6g.large"
  allocated_storage            = 300
  db_name                      = "scan"
  username                     = "scan_admin"
  manage_master_user_password  = true
  db_subnet_group_name         = aws_db_subnet_group.main.name
  vpc_security_group_ids       = [aws_security_group.db.id]
  publicly_accessible          = false
  storage_encrypted            = true
  multi_az                     = true
  backup_retention_period      = 7
  performance_insights_enabled = true
  deletion_protection          = true
  skip_final_snapshot          = false
  final_snapshot_identifier    = "scan-${var.environment}-final"
  copy_tags_to_snapshot        = true
  apply_immediately            = true
}
